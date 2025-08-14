require 'spec_helper'

# Note that #

RSpec.describe Scimitar::Lists::QueryParser do

  # We use the dummy app's MockUser class, so need a database connection from
  # that app too. ActiveRecord can then escape column values, generate SQL and
  # so-forth, and we can run tests to check on that output to verify that
  # the gem has instructed ActiveRecord appropriately.
  #
  require_relative '../../../apps/dummy/app/models/mock_user.rb'

  before :each do
    @instance = described_class.new(MockUser.new.scim_queryable_attributes())
  end

  # ===========================================================================
  # BASIC PARSING
  #
  # Adapted from SCIM Query Filter Parser's non-RSpec tests.
  # ===========================================================================

  context 'basic parsing' do
    it "empty string" do
      @instance.parse("")

      rpn = @instance.rpn
      expect(rpn).to be_empty

      tree = @instance.tree
      expect(tree).to be_empty
    end

    it "user name equals" do
      @instance.parse(%Q(userName eq "bjensen"))

      rpn = @instance.rpn
      expect('userName').to eql(rpn[0])
      expect('"bjensen"').to eql(rpn[1])
      expect('eq').to eql(rpn[2])

      tree = @instance.tree
      expect('eq').to eql(tree[0])
      expect('userName').to eql(tree[1])
      expect('"bjensen"').to eql(tree[2])
    end

    it "family name equals" do
      @instance.parse(%Q(name.familyName co "O'Malley"))

      rpn = @instance.rpn
      expect('name.familyName').to eql(rpn[0])
      expect(%Q("O'Malley")).to eql(rpn[1])
      expect('co').to eql(rpn[2])

      tree = @instance.tree
      expect('co').to eql(tree[0])
      expect('name.familyName').to eql(tree[1])
      expect(%Q("O'Malley")).to eql(tree[2])
    end

    it "extended attribute equals" do
      @instance.parse(%Q(primaryEmail eq "foo@bar.com"))

      rpn = @instance.rpn
      expect('primaryEmail').to eql(rpn[0])
      expect(%Q("foo@bar.com")).to eql(rpn[1])
      expect('eq').to eql(rpn[2])
    end

    it "user name starts with" do
      @instance.parse(%Q(userName sw "J"))

      rpn = @instance.rpn
      expect('userName').to eql(rpn[0])
      expect(%Q("J")).to eql(rpn[1])
      expect('sw').to eql(rpn[2])

      tree = @instance.tree
      expect('sw').to eql(tree[0])
      expect('userName').to eql(tree[1])
      expect('"J"').to eql(tree[2])
    end

    it "title present" do
      @instance.parse(%Q(title pr))

      rpn = @instance.rpn
      expect('title').to eql(rpn[0])
      expect('pr').to eql(rpn[1])

      tree = @instance.tree
      expect('pr').to eql(tree[0])
      expect('title').to eql(tree[1])
    end

    it "last modified greater than" do
      @instance.parse(%Q(meta.lastModified gt "2011-05-13T04:42:34Z"))

      rpn = @instance.rpn
      expect('meta.lastModified').to eql(rpn[0])
      expect('"2011-05-13T04:42:34Z"').to eql(rpn[1])
      expect('gt').to eql(rpn[2])

      tree = @instance.tree
      expect('gt').to eql(tree[0])
      expect('meta.lastModified').to eql(tree[1])
      expect('"2011-05-13T04:42:34Z"').to eql(tree[2])
    end

    it "last modified greater than or equal to" do
      @instance.parse(%Q(meta.lastModified ge "2011-05-13T04:42:34Z"))

      rpn = @instance.rpn

      expect('meta.lastModified').to eql(rpn[0])
      expect('"2011-05-13T04:42:34Z"').to eql(rpn[1])
      expect('ge').to eql(rpn[2])

      tree = @instance.tree
      expect('ge').to eql(tree[0])
      expect('meta.lastModified').to eql(tree[1])
      expect('"2011-05-13T04:42:34Z"').to eql(tree[2])
    end

    it "last modified less than" do
      @instance.parse(%Q(meta.lastModified lt "2011-05-13T04:42:34Z"))

      rpn = @instance.rpn

      expect('meta.lastModified').to eql(rpn[0])
      expect('"2011-05-13T04:42:34Z"').to eql(rpn[1])
      expect('lt').to eql(rpn[2])

      tree = @instance.tree
      expect('lt').to eql(tree[0])
      expect('meta.lastModified').to eql(tree[1])
      expect('"2011-05-13T04:42:34Z"').to eql(tree[2])
    end

    it "last modified less than or equal to" do
      @instance.parse(%Q(meta.lastModified le "2011-05-13T04:42:34Z"))

      rpn = @instance.rpn

      expect('meta.lastModified').to eql(rpn[0])
      expect('"2011-05-13T04:42:34Z"').to eql(rpn[1])
      expect('le').to eql(rpn[2])

      tree = @instance.tree
      expect('le').to eql(tree[0])
      expect('meta.lastModified').to eql(tree[1])
      expect('"2011-05-13T04:42:34Z"').to eql(tree[2])
    end

    it "title and user type equal" do
      @instance.parse(%Q(title pr and userType eq "Employee"))

      rpn = @instance.rpn

      expect('title').to eql(rpn[0])
      expect('pr').to eql(rpn[1])
      expect('userType').to eql(rpn[2])
      expect('"Employee"').to eql(rpn[3])
      expect('eq').to eql(rpn[4])
      expect('and').to eql(rpn[5])

      tree = @instance.tree
      expect(3).to eql(tree.count)
      expect('and').to eql(tree[0])

      sub = tree[1]
      expect(2).to eql(sub.count)
      expect('pr').to eql(sub[0])
      expect('title').to eql(sub[1])

      sub = tree[2]
      expect(3).to eql(sub.count)
      expect('eq').to eql(sub[0])
      expect('userType').to eql(sub[1])
      expect('"Employee"').to eql(sub[2])
    end

    it "title or user type equal" do
      @instance.parse(%Q(title pr or userType eq "Intern"))

      rpn = @instance.rpn

      expect('title').to eql(rpn[0])
      expect('pr').to eql(rpn[1])
      expect('userType').to eql(rpn[2])
      expect('"Intern"').to eql(rpn[3])
      expect('eq').to eql(rpn[4])
      expect('or').to eql(rpn[5])

      tree = @instance.tree
      expect(3).to eql(tree.count)
      expect('or').to eql(tree[0])

      sub = tree[1]
      expect(2).to eql(sub.count)
      expect('pr').to eql(sub[0])
      expect('title').to eql(sub[1])

      sub = tree[2]
      expect(3).to eql(sub.count)
      expect('eq').to eql(sub[0])
      expect('userType').to eql(sub[1])
      expect('"Intern"').to eql(sub[2])
    end

    it "compound filter" do
      @instance.parse(%Q{userType eq "Employee" and (emails co "example.com" or emails co "example.org")})

      rpn = @instance.rpn

      expect('userType').to eql(rpn[0])
      expect('"Employee"').to eql(rpn[1])
      expect('eq').to eql(rpn[2])
      expect('emails').to eql(rpn[3])
      expect('"example.com"').to eql(rpn[4])
      expect('co').to eql(rpn[5])
      expect('emails').to eql(rpn[6])
      expect('"example.org"').to eql(rpn[7])
      expect('co').to eql(rpn[8])
      expect('or').to eql(rpn[9])
      expect('and').to eql(rpn[10])

      tree = @instance.tree
      expect(3).to eql(tree.count)
      expect('and').to eql(tree[0])

      sub = tree[1]
      expect(3).to eql(sub.count)
      expect('eq').to eql(sub[0])
      expect('userType').to eql(sub[1])
      expect('"Employee"').to eql(sub[2])

      sub = tree[2]
      expect(3).to eql(sub.count)
      expect('or').to eql(sub[0])

      expect(3).to eql(sub[1].count)
      expect('co').to eql(sub[1][0])
      expect('emails').to eql(sub[1][1])
      expect('"example.com"').to eql(sub[1][2])

      expect(3).to eql(sub[2].count)
      expect('co').to eql(sub[2][0])
      expect('emails').to eql(sub[2][1])
      expect('"example.org"').to eql(sub[2][2])
    end

    context 'with errors' do
      it 'unsupported operator' do
        expect { @instance.parse('userName zz "Foo"') }.to raise_error(Scimitar::FilterError)
      end

      it 'misplaced operator' do
        expect(@instance).to receive(:assert_not_op).twice.and_call_original
        expect(@instance).to receive(:assert_op).once.and_call_original
        expect { @instance.parse('userName eq pr') }.to raise_error(Scimitar::FilterError)
      end

      it 'missing logical operator' do
        expect(@instance).to receive(:assert_op).twice.and_call_original
        expect(@instance).to receive(:assert_not_op).once.and_call_original
        expect { @instance.parse('userName pr userType eq "Foo"') }.to raise_error(Scimitar::FilterError)
      end

      it 'missing closing bracket' do
        expect(@instance).to receive(:assert_close).once.and_call_original
        expect { @instance.parse('userName pr and (userType eq "Foo"') }.to raise_error(Scimitar::FilterError)
      end

      it 'trailing junk' do
        expect(@instance).to receive(:assert_eos).once.and_call_original
        expect { @instance.parse('userName eq "Foo" )') }.to raise_error(Scimitar::FilterError)
      end
    end # "context 'with errors' do"
  end # "context 'basic parsing' do"

  # ===========================================================================
  # INTERNAL FILTER FLATTENING
  #
  # Attempts to reduce query parser complexity while tolerating a wider range
  # of input "styles" of filter
  # ===========================================================================

  context '#flatten_filter (private)' do
    context 'when flattening is not needed' do
      it 'and with one filter, binary operator' do
        result = @instance.send(:flatten_filter, 'userType eq "Admin"')
        expect(result).to eql('userType eq "Admin"')
      end

      it 'and with one filter, unary operator' do
        result = @instance.send(:flatten_filter, 'userType pr')
        expect(result).to eql('userType pr')
      end

      it 'and two filters, unary then binary operator' do
        result = @instance.send(:flatten_filter, 'userType pr and userName eq "Foo"')
        expect(result).to eql('userType pr and userName eq "Foo"')
      end
    end # "context 'when flattening is not needed' do"

    context 'when flattening is needed' do
      it 'flattens simple cases' do
        result = @instance.send(:flatten_filter, 'userType eq "Employee" and emails[type eq "work" and value co "@example.com"]')
        expect(result).to eql('userType eq "Employee" and emails.type eq "work" and emails.value co "@example.com"')
      end

      it 'correctly processes more than one inner filter' do
        result = @instance.send(:flatten_filter, 'emails[type eq "work" and value co "@example.com"] or userType eq "Admin" or ims[type eq "xmpp" and value co "@foo.com"]')
        expect(result).to eql('emails.type eq "work" and emails.value co "@example.com" or userType eq "Admin" or ims.type eq "xmpp" and ims.value co "@foo.com"')
      end

      it 'flattens nested cases' do
        result = @instance.send(:flatten_filter, 'userType ne "Employee" and not (emails[value co "example.com" or (value co "example.org")]) and userName="foo"')
        expect(result).to eql('userType ne "Employee" and not (emails.value co "example.com" or (emails.value co "example.org")) and userName="foo"')
      end

      it 'handles spaces in quoted values' do
        result = @instance.send(:flatten_filter, 'userType eq "Employee spaces" or userName pr and emails[type eq "with spaces" and value co "@example.com"]')
        expect(result).to eql('userType eq "Employee spaces" or userName pr and emails.type eq "with spaces" and emails.value co "@example.com"')
      end

      it 'handles escaped quotes in quoted values' do
        result = @instance.send(:flatten_filter, 'userType eq "Emplo\\"yee" and emails[type eq "\\"work\\"" and value co "@example.com"]')
        expect(result).to eql('userType eq "Emplo\\"yee" and emails.type eq "\\"work\\"" and emails.value co "@example.com"')
      end

      it 'handles escaped opening square brackets' do
        result = @instance.send(:flatten_filter, 'userType eq \\[Employee and emails[type eq "work" and value co "@example.com"]')
        expect(result).to eql('userType eq \\[Employee and emails.type eq "work" and emails.value co "@example.com"')
      end

      it 'handles escaped closing square brackets' do
        result = @instance.send(:flatten_filter, 'userType eq "Employee" and emails[type eq "work" and value co Unquoted\\]]')
        expect(result).to eql('userType eq "Employee" and emails.type eq "work" and emails.value co Unquoted\\]')
      end

      it 'handles spaces before closing square brackets' do
        result = @instance.send(:flatten_filter, 'emails[type eq "work" and value co "@example.com"    ] or userType eq "Admin" or ims[type eq "xmpp" and value co "@foo.com"]')
        expect(result).to eql('emails.type eq "work" and emails.value co "@example.com" or userType eq "Admin" or ims.type eq "xmpp" and ims.value co "@foo.com"')
      end

      it 'handles an example previously described as unsupported in README.md' do
        result = @instance.send(:flatten_filter, 'filter=userType eq "Employee" and emails[type eq "work" and value co "@example.com"]')
        expect(result).to eql('filter=userType eq "Employee" and emails.type eq "work" and emails.value co "@example.com"')
      end

      # https://github.com/pond/scimitar/issues/116
      #
      context 'with schema IDs (GitHub issue #116)' do
        it 'handles simple attributes' do
          result = @instance.send(:flatten_filter, 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:employeeId eq "gsar"')
          expect(result).to eql('employeeId eq "gsar"')
        end

        it 'handles dotted attribute paths' do
          result = @instance.send(:flatten_filter, 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:imaginary.path eq "gsar"')
          expect(result).to eql('imaginary.path eq "gsar"')
        end

        it 'replaces all examples' do
          result = @instance.send(:flatten_filter, 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:employeeId eq "gsar" or urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:imaginary.path eq "gsar"')
          expect(result).to eql('employeeId eq "gsar" or imaginary.path eq "gsar"')
        end

        it 'handles the square bracket form with schema ID at the root' do
          result = @instance.send(:flatten_filter, 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User[employeeId eq "gsar"')
          expect(result).to eql('employeeId eq "gsar"')
        end

        it 'handles the square bracket form with schema ID and attribute at the root' do
          result = @instance.send(:flatten_filter, 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:imaginary[path eq "gsar"')
          expect(result).to eql('imaginary.path eq "gsar"')
        end
      end

      # https://github.com/pond/scimitar/issues/115
      #
      context 'broken filters from Microsoft (GitHub issue #115)' do
        it 'work with "eq"' do
          result = @instance.send(:flatten_filter, 'emails[type eq "work"].value eq "foo@bar.com"')
          expect(result).to eql('emails.type eq "work" and emails.value eq "foo@bar.com"')
        end

        it 'work with "ne"' do # (just check a couple of operators, not all!)
          result = @instance.send(:flatten_filter, 'emails[type eq "work"].value ne "foo@bar.com"')
          expect(result).to eql('emails.type eq "work" and emails.value ne "foo@bar.com"')
        end

        it 'preserve input case' do
          result = @instance.send(:flatten_filter, 'emaiLs[TYPE eq "work"].valUE eq "FOO@bar.com"')
          expect(result).to eql('emaiLs.TYPE eq "work" and emaiLs.valUE eq "FOO@bar.com"')
        end

        # At the time of writing, this was used in a "belt and braces" request
        # spec in 'active_record_backed_resources_controller_spec.rb'.
        #
        it 'handles more complex, hypothetical cases' do
          result = @instance.send(:flatten_filter, 'name[givenName eq "FOO"].familyName pr and emails ne "home_1@test.com"')
          expect(result).to eql('name.givenName eq "FOO" and name.familyName pr and emails ne "home_1@test.com"')
        end
      end # "context 'broken filters from Microsoft' do"
    end # "context 'when flattening is needed' do"

    context 'with bad filters' do
      it 'missing operator' do
        expect { @instance.send(:flatten_filter, 'emails.type "work"') }.to raise_error(RuntimeError, 'Expected operator')
      end

      it 'unexpected closing "]"' do
        expect { @instance.send(:flatten_filter, 'emails.type eq "work"]') }.to raise_error(RuntimeError, 'Unexpected closing "]"')
      end

      it 'logic operator is neither "and" nor "or"' do
        expect { @instance.send(:flatten_filter, 'userName pr nand userType pr') }.to raise_error(RuntimeError, 'Expected "and" or "or"')
      end
    end
  end # "context '#flatten_filter (private)' do"

  # ===========================================================================
  # ACTIVERECORD QUERIES
  #
  # If you have issues here, check that private method unit tests are passing
  # before worrying about these higher-level checks.
  # ===========================================================================

  context '#to_activerecord_query' do

    # Means we don't need to iterate over every SCIM operator here, as we can
    # have confidence that the lower level unit tests provide coverage.
    #
    it 'uses heavily-unit-tested #apply_scim_filter under the hood' do
      @instance.parse("name.familyName EQ \"BAZ\"") # Note "EQ" upper case

      expect(@instance).to receive(:apply_scim_filter).with(
        base_scope:     MockUser.all,
        scim_attribute: 'name.familyName',
        scim_operator:  'eq', # Note 'eq' lower case
        scim_parameter: '"BAZ"',
        case_sensitive: false
      )

      @instance.to_activerecord_query(MockUser.all)
    end

    # Technically tests #parse :-) but I hit this when writing the test that
    # immediately follows - this location will do for now, since OK in context.
    #
    it 'complains about incorrectly quoted queries' do
      expect { @instance.parse('name.familyName co B%_AZ') }.to raise_error(Scimitar::FilterError)
    end

    it 'escapes values sent into ILIKE statements' do
      @instance.parse('name.familyName co "B%_AZ"')
      query = @instance.to_activerecord_query(MockUser.all)

      expect(query.to_sql).to eql(%q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" ILIKE '%B\%\_AZ%'})
    end

    it 'operates correctly with a few hand-chosen basic queries' do
      user_1 = MockUser.create(username: '1', first_name: 'Jane', last_name: 'Doe')
      user_2 = MockUser.create(username: '2', first_name: 'John', last_name: 'Smithe')
      user_3 = MockUser.create(username: '3',                     last_name: 'Davis')

      # Test the various "LIKE" wildcards

      @instance.parse('name.familyName co o') # Last name contains 'o'
      query = @instance.to_activerecord_query(MockUser.all)

      expect(query.count).to eql(1)
      expect(query.pluck(:primary_key)).to eql([user_1.primary_key])

      @instance.parse('name.givenName sw J') # First name starts with 'J'
      query = @instance.to_activerecord_query(MockUser.all)

      expect(query.count).to eql(2)
      expect(query.pluck(:primary_key)).to match_array([user_1.primary_key, user_2.primary_key])

      @instance.parse('name.familyName ew he') # Last name ends with 'he'
      query = @instance.to_activerecord_query(MockUser.all)

      expect(query.count).to eql(1)
      expect(query.pluck(:primary_key)).to eql([user_2.primary_key])

      # Test presence

      @instance.parse('name.givenName pr') # First name is present
      query = @instance.to_activerecord_query(MockUser.all)

      expect(query.count).to eql(2)
      expect(query.pluck(:primary_key)).to match_array([user_1.primary_key, user_2.primary_key])

      # Test a simple not-equals, but use a custom starting scope. Note that
      # the query would find "user_3" *except* there is no first name defined
      # at all, and in SQL, "foo != bar" is *not* a match if foo IS NULL.

      @instance.parse('name.givenName ne Bob') # First name is not 'Bob'
      query = @instance.to_activerecord_query(MockUser.where.not('first_name' => 'John'))

      expect(query.count).to eql(1)
      expect(query.pluck(:primary_key)).to match_array([user_1.primary_key])
    end

    context 'when mapped to multiple columns' do
      context 'with binary operators' do
        it 'reads across all using OR' do
          @instance.parse('emails eq "any@test.com"')
          query = @instance.to_activerecord_query(MockUser.all)

          expect(query.to_sql).to eql(%q{SELECT "mock_users".* FROM "mock_users" WHERE ("mock_users"."work_email_address" ILIKE 'any@test.com' OR "mock_users"."home_email_address" ILIKE 'any@test.com')})
        end

        it 'works with other query elements using correct precedence' do
          @instance.parse('name.familyName eq "John" and emails eq "any@test.com"')
          query = @instance.to_activerecord_query(MockUser.all)

          expect(query.to_sql).to eql(%q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" ILIKE 'John' AND ("mock_users"."work_email_address" ILIKE 'any@test.com' OR "mock_users"."home_email_address" ILIKE 'any@test.com')})
        end
      end # "context 'with binary operators' do"

      context 'with unary operators' do
        it 'reads across all using OR' do
          @instance.parse('emails pr')
          query = @instance.to_activerecord_query(MockUser.all)

          expect(query.to_sql).to eql(%q{SELECT "mock_users".* FROM "mock_users" WHERE (("mock_users"."work_email_address" != '' AND "mock_users"."work_email_address" IS NOT NULL) OR ("mock_users"."home_email_address" != '' AND "mock_users"."home_email_address" IS NOT NULL))})
        end

        it 'works with other query elements using correct precedence' do
          @instance.parse('name.familyName eq "John" and emails pr')
          query = @instance.to_activerecord_query(MockUser.all)

          expect(query.to_sql).to eql(%q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" ILIKE 'John' AND (("mock_users"."work_email_address" != '' AND "mock_users"."work_email_address" IS NOT NULL) OR ("mock_users"."home_email_address" != '' AND "mock_users"."home_email_address" IS NOT NULL))})
        end
      end # "context 'with unary operators' do
    end # "context 'when mapped to multiple columns' do"

    context 'when instructed to ignore an attribute' do
      it 'ignores it' do
        @instance.parse('emails.type eq "work"')
        query = @instance.to_activerecord_query(MockUser.all)

        expect(query.to_sql).to eql(%q{SELECT "mock_users".* FROM "mock_users"})
      end
    end # "context 'when instructed to ignore an attribute' do"

    context 'when an arel column is mapped' do
      let(:scope_with_groups) { MockUser.left_joins(:mock_groups) }

      context 'with binary operators' do
        it 'reads across all using OR' do
          @instance.parse('groups eq "12345"')
          query = @instance.to_activerecord_query(scope_with_groups)

          expect(query.to_sql).to eql(<<~SQL.squish)
            SELECT "mock_users".*
            FROM "mock_users"
              LEFT OUTER JOIN "mock_groups_users" ON "mock_groups_users"."mock_user_id" = "mock_users"."primary_key"
              LEFT OUTER JOIN "mock_groups" ON "mock_groups"."id" = "mock_groups_users"."mock_group_id"
            WHERE "mock_groups"."id" ILIKE 12345
          SQL
        end

        it 'works with other query elements using correct precedence' do
          @instance.parse('groups eq "12345" and emails eq "any@test.com"')
          query = @instance.to_activerecord_query(scope_with_groups)

          expect(query.to_sql).to eql(<<~SQL.squish)
            SELECT "mock_users".*
            FROM "mock_users"
              LEFT OUTER JOIN "mock_groups_users" ON "mock_groups_users"."mock_user_id" = "mock_users"."primary_key"
              LEFT OUTER JOIN "mock_groups" ON "mock_groups"."id" = "mock_groups_users"."mock_group_id"
            WHERE "mock_groups"."id" ILIKE 12345 AND ("mock_users"."work_email_address" ILIKE 'any@test.com' OR "mock_users"."home_email_address" ILIKE 'any@test.com')
          SQL
        end
      end # "context 'with binary operators' do"

      context 'with unary operators' do
        it 'reads across all using OR' do
          @instance.parse('groups pr')
          query = @instance.to_activerecord_query(scope_with_groups)

          expect(query.to_sql).to eql(<<~SQL.squish)
            SELECT "mock_users".*
            FROM "mock_users"
              LEFT OUTER JOIN "mock_groups_users" ON "mock_groups_users"."mock_user_id" = "mock_users"."primary_key"
              LEFT OUTER JOIN "mock_groups" ON "mock_groups"."id" = "mock_groups_users"."mock_group_id"
            WHERE ("mock_groups"."id" != NULL AND "mock_groups"."id" IS NOT NULL)
          SQL
        end

        it 'works with other query elements using correct precedence' do
          @instance.parse('name.familyName eq "John" and groups pr')
          query = @instance.to_activerecord_query(scope_with_groups)

          expect(query.to_sql).to eql(<<~SQL.squish)
            SELECT "mock_users".*
            FROM "mock_users"
              LEFT OUTER JOIN "mock_groups_users" ON "mock_groups_users"."mock_user_id" = "mock_users"."primary_key"
              LEFT OUTER JOIN "mock_groups" ON "mock_groups"."id" = "mock_groups_users"."mock_group_id"
            WHERE "mock_users"."last_name" ILIKE 'John' AND ("mock_groups"."id" != NULL AND "mock_groups"."id" IS NOT NULL)
          SQL
        end
      end # "context 'with unary operators' do
    end # "context 'when an arel column is mapped' do"

    context 'with complex cases' do
      context 'using AND' do
        it 'generates expected SQL' do
          @instance.parse('name.givenName pr AND name.familyName ne "Doe"')
          query = @instance.to_activerecord_query(MockUser.all)

          expect(query.to_sql).to eql(%q{SELECT "mock_users".* FROM "mock_users" WHERE ("mock_users"."first_name" != '' AND "mock_users"."first_name" IS NOT NULL) AND "mock_users"."last_name" NOT ILIKE 'Doe'})
        end

        it 'finds expected items' do
          user_1 = MockUser.create(username: '1', first_name: 'Jane', last_name: 'Davis')
          user_2 = MockUser.create(username: '2', first_name: 'John', last_name: 'Doe')
          user_3 = MockUser.create(username: '3',                     last_name: 'Doe')

          @instance.parse('name.givenName pr AND name.familyName eq "Doe"')
          query = @instance.to_activerecord_query(MockUser.all)

          expect(query.count).to eql(1)
          expect(query.pluck(:primary_key)).to match_array([user_2.primary_key])
        end
      end # "context 'simple AND' do"

      context 'using OR' do
        it 'generates expected SQL' do
          @instance.parse('name.givenName pr OR name.familyName eq "Doe"')
          query = @instance.to_activerecord_query(MockUser.all)

          expect(query.to_sql).to eql(%q{SELECT "mock_users".* FROM "mock_users" WHERE (("mock_users"."first_name" != '' AND "mock_users"."first_name" IS NOT NULL) OR "mock_users"."last_name" ILIKE 'Doe')})
        end

        it 'finds expected items' do
          user_1 = MockUser.create(username: '1', first_name: 'Jane', last_name: 'Davis')
          user_2 = MockUser.create(username: '2',                     last_name: 'Doe')
          user_3 = MockUser.create(username: '3',                     last_name: 'Smith')

          @instance.parse('name.givenName pr OR name.familyName eq "Doe"')
          query = @instance.to_activerecord_query(MockUser.all)

          expect(query.count).to eql(2)
          expect(query.pluck(:primary_key)).to match_array([user_1.primary_key, user_2.primary_key])
        end
      end # "context 'simple OR' do"

      context 'combined AND, OR and parentheses' do
        it 'generates expected SQL' do
          @instance.parse('name.givenName eq "Jane" and (name.familyName co "avi" or name.familyName ew "ith")')
          query = @instance.to_activerecord_query(MockUser.all)

          expect(query.to_sql).to eql(%q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."first_name" ILIKE 'Jane' AND ("mock_users"."last_name" ILIKE '%avi%' OR "mock_users"."last_name" ILIKE '%ith')})
        end

        it 'combined parentheses generates expected SQL' do
          @instance.parse('(name.givenName eq "Jane" OR name.givenName eq "Jaden") and (name.familyName co "avi" or name.familyName ew "ith")')
          query = @instance.to_activerecord_query(MockUser.all)

          expect(query.to_sql).to eql(%q{SELECT "mock_users".* FROM "mock_users" WHERE ("mock_users"."first_name" ILIKE 'Jane' OR "mock_users"."first_name" ILIKE 'Jaden') AND ("mock_users"."last_name" ILIKE '%avi%' OR "mock_users"."last_name" ILIKE '%ith')})
        end

        it 'finds expected items' do
          user_1 = MockUser.create(username: '1', first_name: 'Jane', last_name: 'Davis')   # Match
          user_2 = MockUser.create(username: '2', first_name: 'Jane', last_name: 'Smith')   # Match
          user_3 = MockUser.create(username: '3', first_name: 'Jane', last_name: 'Moreith') # Match
          user_4 = MockUser.create(username: '4', first_name: 'Jane', last_name: 'Doe')     # No last name match
          user_5 = MockUser.create(username: '5', first_name: 'Doe',  last_name: 'Smith')   # No first name match
          user_6 = MockUser.create(username: '6', first_name: 'Bill', last_name: 'Davis')   # No first name match
          user_7 = MockUser.create(username: '7',                     last_name: 'Davis')   # Missing first name
          user_8 = MockUser.create(username: '8',                     last_name: 'Smith')   # Missing first name

          @instance.parse('name.givenName eq "Jane" and (name.familyName co "avi" or name.familyName ew "ith")')
          query = @instance.to_activerecord_query(MockUser.all)

          expect(query.count).to eql(3)
          expect(query.pluck(:primary_key)).to match_array([user_1.primary_key, user_2.primary_key, user_3.primary_key])
        end
      end # "context 'combined AND and OR' do"

      context 'when flattening is needed' do
        it 'generates expected SQL' do
          @instance.parse('name[givenName eq "Jane" and (familyName co "avi" or familyName ew "ith")]')
          query = @instance.to_activerecord_query(MockUser.all)

          expect(query.to_sql).to eql(%q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."first_name" ILIKE 'Jane' AND ("mock_users"."last_name" ILIKE '%avi%' OR "mock_users"."last_name" ILIKE '%ith')})
        end
      end # "context 'when flattening is needed' do"
    end # "context 'complex cases' do"
  end # "context '#to_activerecord_query' do"

  context "#to_mongoid_query" do
    context "when simple queries are used" do
      it "generates expected Mongoid eq queries" do
        @instance.parse('name.familyName eq "Doe"')
        query = @instance.to_mongoid_query

        expect(query).to eql(last_name: { "$eq" => "Doe" })
      end

      it "generates expected Mongoid ne queries" do
        @instance.parse('name.familyName ne "Doe"')
        query = @instance.to_mongoid_query

        expect(query).to eql(last_name: { "$ne" => "Doe" })
      end
    end

    context "when complex comparisons are used" do
      it "generates expected Mongoid pr queries" do
        @instance.parse('name.givenName pr')
        query = @instance.to_mongoid_query

        expect(query).to eql(first_name: { "$exists" => true, "$ne" => nil })
      end

      it "generates expected Mongoid co queries" do
        @instance.parse('name.familyName co "Smith"')
        query = @instance.to_mongoid_query

        expect(query).to eql(last_name: /Smith/)
      end
    end

    context "when combinations are user" do
      it "generates expected Mongoid queries for AND and OR" do
        @instance.parse('name.givenName eq "Jane" and (name.familyName co "Smith" or name.familyName eq "Doe")')
        query = @instance.to_mongoid_query

        expect(query).to eql(
          "$and" => [
            { first_name: { "$eq" => "Jane" }},
            { "$or" => [{ last_name: /Smith/ }, { last_name: { "$eq" => "Doe" }}]}
          ]
        )
      end
    end
  end

  # ===========================================================================
  # PRIVATE METHODS
  # ===========================================================================

  context 'internal method' do

    # =========================================================================
    # Attributes
    # =========================================================================

    context '#activerecord_columns' do
      it 'returns a column in an array' do
        expect(@instance.send(:activerecord_columns, 'name.familyName')).to eql([:last_name])
      end

      it 'returns multiple column in an array' do
        expect(@instance.send(:activerecord_columns, 'emails')).to eql([:work_email_address, :home_email_address])
      end

      it 'returns empty for "ignore"' do
        expect(@instance.send(:activerecord_columns, 'emails.type')).to be_empty
      end

      it 'complains if there is no column present' do
        expect { @instance.send(:activerecord_columns, nil) }.to raise_error(Scimitar::FilterError)
        expect { @instance.send(:activerecord_columns, '' ) }.to raise_error(Scimitar::FilterError)
      end

      it 'complains if there is no column mapping available' do
        expect { @instance.send(:activerecord_columns, 'userName') }.to raise_error(Scimitar::FilterError)
      end

      it 'complains about malformed declarations' do
        local_instance = described_class.new(
          {
            'name.givenName' => { wut: true }
          }
        )

        expect { local_instance.send(:activerecord_columns, 'name.givenName' ) }.to raise_error(RuntimeError)
      end
    end # "context '#activerecord_columns' do"

    # =========================================================================
    # Parameters
    # =========================================================================

    context '#activerecord_parameter' do
      it 'returns a blank string if a parameter is missing' do
        expect(@instance.send(:activerecord_parameter, nil )).to eql('')
        expect(@instance.send(:activerecord_parameter, ''  )).to eql('')
        expect(@instance.send(:activerecord_parameter, '  ')).to eql('')
      end

      it 'returns the parameter if present' do
        expect(@instance.send(:activerecord_parameter, 'BAZ')).to eql('BAZ')
      end

      it 'removes surrounding quotes if present' do
        expect(@instance.send(:activerecord_parameter, '"BA"Z"')).to eql('BA"Z')
        expect(@instance.send(:activerecord_parameter, '"BA"Z' )).to eql('"BA"Z')
        expect(@instance.send(:activerecord_parameter, 'BA"Z"' )).to eql('BA"Z"')
      end
    end # "context '#parameter' do"

    # =========================================================================
    # Low level queries
    # =========================================================================

    context '#apply_scim_filter' do

      # Use 'let' to define :binary_expectations and :unary_operators, mapping
      # lower case SCIM operators to expected SQL output assuming a base scope
      # of "MockUser.all".
      #
      shared_examples 'generates expected query data' do | is_case_sensitive: |
        it 'with binary operators' do

          # Self-check: Is test coverage up to date?
          #
          expect(Scimitar::Lists::QueryParser::BINARY_OPERATORS.to_a - binary_expectations().keys).to match_array(['and', 'or'])

          binary_expectations().each do | input, expected_output |
            query = @instance.send(
              :apply_scim_filter,

              base_scope:     MockUser.all,
              scim_attribute: 'name.familyName',
              scim_operator:  input,
              scim_parameter: '"BAZ"',
              case_sensitive: is_case_sensitive
            )

            # Run a count just to prove the result is at least of valid syntax and
            # check the SQL against expectations.
            #
            expect { query.count }.to_not raise_error
            expect(query.to_sql).to eql(expected_output)
          end
        end

        it 'with unary operators' do

          # Self-check: Is test coverage up to date?
          #
          expect(Scimitar::Lists::QueryParser::UNARY_OPERATORS.to_a - unary_expectations().keys).to be_empty

          unary_expectations().each do | input, expected_output |
            query = @instance.send(
              :apply_scim_filter,

              base_scope:     MockUser.all,
              scim_attribute: 'name.familyName',
              scim_operator:  input,
              scim_parameter: nil,
              case_sensitive: is_case_sensitive
            )

            # Run a count just to prove the result is at least of valid syntax and
            # check the SQL against expectations.
            #
            expect { query.count }.to_not raise_error
            expect(query.to_sql).to eql(expected_output)
          end
        end
      end # "shared_examples 'generates expected query data' do"

      context 'case sensitive' do
        let(:binary_expectations) {{
          'eq' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" = 'BAZ'},
          'ne' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" != 'BAZ'},
          'gt' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" > 'BAZ'},
          'ge' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" >= 'BAZ'},
          'lt' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" < 'BAZ'},
          'le' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" <= 'BAZ'},
          'co' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" LIKE '%BAZ%'},
          'sw' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" LIKE 'BAZ%'},
          'ew' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" LIKE '%BAZ'},
        }}

        let(:unary_expectations) {{
          'pr' => %q{SELECT "mock_users".* FROM "mock_users" WHERE ("mock_users"."last_name" != '' AND "mock_users"."last_name" IS NOT NULL)},
        }}

        include_examples 'generates expected query data', is_case_sensitive: true
      end #  "context 'case sensitive' do"

      context 'case insensitive' do
        let(:binary_expectations) {{
          'eq' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" ILIKE 'BAZ'},
          'ne' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" NOT ILIKE 'BAZ'},
          'gt' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" > 'BAZ'},
          'ge' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" >= 'BAZ'},
          'lt' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" < 'BAZ'},
          'le' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" <= 'BAZ'},
          'co' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" ILIKE '%BAZ%'},
          'sw' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" ILIKE 'BAZ%'},
          'ew' => %q{SELECT "mock_users".* FROM "mock_users" WHERE "mock_users"."last_name" ILIKE '%BAZ'},
        }}

        let(:unary_expectations) {{
          'pr' => %q{SELECT "mock_users".* FROM "mock_users" WHERE ("mock_users"."last_name" != '' AND "mock_users"."last_name" IS NOT NULL)},
        }}

        include_examples 'generates expected query data', is_case_sensitive: false
      end # "context 'case insensitive' do"

      context 'error handling' do
        it 'raises Scimitar::FilterError for unsupported operators' do
          expect {
            query = @instance.send(
              :apply_scim_filter,

              base_scope:     MockUser.all,
              scim_attribute: 'name.familyName',
              scim_operator:  'zz',
              scim_parameter: '"BAZ"',
              case_sensitive: false
            )
          }.to raise_error(Scimitar::FilterError)
        end

        it 'raises Scimitar::FilterError for unsupported columnsx' do
          expect(@instance).to receive(:activerecord_columns).with('name.familyName').and_return(['non_existant_column_name'])
          expect {
            query = @instance.send(
              :apply_scim_filter,

              base_scope:     MockUser.all,
              scim_attribute: 'name.familyName',
              scim_operator:  'eq',
              scim_parameter: '"BAZ"',
              case_sensitive: false
            )
          }.to raise_error(Scimitar::FilterError)
        end
      end # "context 'error handling' do"
    end # "context '#apply_scim_filter' do
  end # "context 'unit tests for internal methods' do"
end # "RSpec.describe Scimitar::Lists::QueryParser do"
