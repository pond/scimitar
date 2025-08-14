require 'spec_helper'
require 'time'

RSpec.describe Scimitar::ActiveRecordBackedResourcesController do
  before :each do
    allow_any_instance_of(Scimitar::ApplicationController).to receive(:authenticated?).and_return(true)

    # If a sort order is unspecified, the controller defaults to ID ascending.
    # With UUID based IDs, testing life is made easier by ensuring that the
    # creation order matches an ascending UUID sort order (which is what would
    # happen if we were using integer primary keys).
    #
    lmt = Time.parse("2023-01-09 14:25:00 +1300")
    ids = 3.times.map { SecureRandom.uuid }.sort()

    @u1 = MockUser.create!(primary_key: ids.shift(), username: '1', first_name: 'Foo', last_name: 'Ark', home_email_address: 'home_1@test.com', scim_uid: '001', created_at: lmt, updated_at: lmt + 1)
    @u2 = MockUser.create!(primary_key: ids.shift(), username: '2', first_name: 'Foo', last_name: 'Bar', home_email_address: 'home_2@test.com', scim_uid: '002', created_at: lmt, updated_at: lmt + 2, password: 'oldpassword')
    @u3 = MockUser.create!(primary_key: ids.shift(), username: '3', first_name: 'Foo',                   home_email_address: 'home_3@test.com', scim_uid: '003', created_at: lmt, updated_at: lmt + 3)

    @g1 = MockGroup.create!(display_name: 'Group 1')
    @g2 = MockGroup.create!(display_name: 'Group 2')
    @g3 = MockGroup.create!(display_name: 'Group 3')
  end

  # ===========================================================================

  context '#index' do
    context 'with no items' do
      before :each do
        MockUser.delete_all
      end

      it 'returns empty list' do
        expect_any_instance_of(MockUsersController).to receive(:index).once.and_call_original
        get '/Users', params: { format: :scim }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['totalResults']).to eql(0)
        expect(result['startIndex'  ]).to eql(1)
        expect(result['itemsPerPage']).to eql(100)
      end
    end # "context 'with no items' do"

    context 'with items' do
      context 'with a UUID, renamed primary key column' do
        it 'returns all items' do
          get '/Users', params: { format: :scim }

          expect(response.status                 ).to eql(200)
          expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

          result = JSON.parse(response.body)

          expect(result['totalResults']).to eql(3)
          expect(result['Resources'].size).to eql(3)

          ids = result['Resources'].map { |resource| resource['id'] }
          expect(ids).to match_array([@u1.primary_key.to_s, @u2.primary_key.to_s, @u3.primary_key.to_s])

          usernames = result['Resources'].map { |resource| resource['userName'] }
          expect(usernames).to match_array(['1', '2', '3'])
        end
      end # "context 'with a UUID, renamed primary key column' do"

      context 'with an integer, conventionally named primary key column' do
        it 'returns all items' do
          get '/Groups', params: { format: :scim }

          expect(response.status                 ).to eql(200)
          expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

          result = JSON.parse(response.body)

          expect(result['totalResults']).to eql(3)
          expect(result['Resources'].size).to eql(3)

          ids = result['Resources'].map { |resource| resource['id'] }
          expect(ids).to match_array([@g1.id.to_s, @g2.id.to_s, @g3.id.to_s])

          usernames = result['Resources'].map { |resource| resource['displayName'] }
          expect(usernames).to match_array(['Group 1', 'Group 2', 'Group 3'])
        end
      end # "context 'with an integer, conventionally named primary key column' do"

      it 'applies a filter, with case-insensitive value comparison' do
        get '/Users', params: {
          format: :scim,
          filter: 'name.givenName eq "FOO" and name.familyName pr and emails ne "home_1@test.com"'
        }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['totalResults']).to eql(1)
        expect(result['Resources'].size).to eql(1)

        ids = result['Resources'].map { |resource| resource['id'] }
        expect(ids).to match_array([@u2.primary_key.to_s])

        usernames = result['Resources'].map { |resource| resource['userName'] }
        expect(usernames).to match_array(['2'])
      end

      it 'returns only the requested attributes' do
        get '/Users', params: {
          format: :scim,
          attributes: "id,name"
        }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['totalResults']).to eql(3)
        expect(result['Resources'].size).to eql(3)

        keys = result['Resources'].map { |resource| resource.keys }.flatten.uniq

        expect(keys).to match_array(%w[
          id
          meta
          name
          schemas
          urn:ietf:params:scim:schemas:extension:enterprise:2.0:User
          urn:ietf:params:scim:schemas:extension:manager:1.0:User
        ])
        expect(result.dig('Resources', 0, 'id')).to eql @u1.primary_key.to_s
        expect(result.dig('Resources', 0, 'name', 'givenName')).to eql 'Foo'
        expect(result.dig('Resources', 0, 'name', 'familyName')).to eql 'Ark'
      end

      # https://github.com/pond/scimitar/issues/37
      #
      it 'applies a filter, with case-insensitive attribute matching (GitHub issue #37)' do
        get '/Users', params: {
          format: :scim,
          filter: 'name.GIVENNAME eq "Foo" and name.Familyname pr and emails ne "home_1@test.com"'
        }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['totalResults']).to eql(1)
        expect(result['Resources'].size).to eql(1)

        ids = result['Resources'].map { |resource| resource['id'] }
        expect(ids).to match_array([@u2.primary_key.to_s])

        usernames = result['Resources'].map { |resource| resource['userName'] }
        expect(usernames).to match_array(['2'])
      end

      # https://github.com/pond/scimitar/issues/115
      #
      it 'handles broken Microsoft filters (GitHub issue #115)' do
        get '/Users', params: {
          format: :scim,
          filter: 'name[givenName eq "FOO"].familyName pr and emails ne "home_1@test.com"'
        }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['totalResults']).to eql(1)
        expect(result['Resources'].size).to eql(1)

        ids = result['Resources'].map { |resource| resource['id'] }
        expect(ids).to match_array([@u2.primary_key.to_s])

        usernames = result['Resources'].map { |resource| resource['userName'] }
        expect(usernames).to match_array(['2'])
      end


      # Strange attribute capitalisation in tests here builds on test coverage
      # for now-fixed GitHub issue #37.
      #
      context '"meta" / IDs (GitHub issue #36)' do
        it 'applies a filter on primary keys, using direct comparison (rather than e.g. case-insensitive operators)' do
          get '/Users', params: {
            format: :scim,
            filter: "id eq \"#{@u3.primary_key}\""
          }

          expect(response.status                 ).to eql(200)
          expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

          result = JSON.parse(response.body)

          expect(result['totalResults']).to eql(1)
          expect(result['Resources'].size).to eql(1)

          ids = result['Resources'].map { |resource| resource['id'] }
          expect(ids).to match_array([@u3.primary_key.to_s])

          usernames = result['Resources'].map { |resource| resource['userName'] }
          expect(usernames).to match_array(['3'])
        end

        it 'applies a filter on external IDs, using direct comparison' do
          get '/Users', params: {
            format: :scim,
            filter: "externalID eq \"#{@u2.scim_uid}\""
          }

          expect(response.status                 ).to eql(200)
          expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

          result = JSON.parse(response.body)

          expect(result['totalResults']).to eql(1)
          expect(result['Resources'].size).to eql(1)

          ids = result['Resources'].map { |resource| resource['id'] }
          expect(ids).to match_array([@u2.primary_key.to_s])

          usernames = result['Resources'].map { |resource| resource['userName'] }
          expect(usernames).to match_array(['2'])
        end

        it 'applies a filter on "meta" entries, using direct comparison' do
          get '/Users', params: {
            format: :scim,
            filter: "Meta.LastModified eq \"#{@u3.updated_at}\""
          }

          expect(response.status                 ).to eql(200)
          expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

          result = JSON.parse(response.body)

          expect(result['totalResults']).to eql(1)
          expect(result['Resources'].size).to eql(1)

          ids = result['Resources'].map { |resource| resource['id'] }
          expect(ids).to match_array([@u3.primary_key.to_s])

          usernames = result['Resources'].map { |resource| resource['userName'] }
          expect(usernames).to match_array(['3'])
        end
      end # "context '"meta" / IDs (GitHub issue #36)' do"

      it 'obeys a page size' do
        get '/Users', params: {
          format: :scim,
          count:  2
        }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['totalResults']).to eql(3)
        expect(result['Resources'].size).to eql(2)

        ids = result['Resources'].map { |resource| resource['id'] }
        expect(ids).to match_array([@u1.primary_key.to_s, @u2.primary_key.to_s])

        usernames = result['Resources'].map { |resource| resource['userName'] }
        expect(usernames).to match_array(['1', '2'])
      end

      it 'obeys start-at-1 offsets' do
        get '/Users', params: {
          format:    :scim,
          startIndex: 2
        }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['totalResults']).to eql(3)
        expect(result['Resources'].size).to eql(2)

        ids = result['Resources'].map { |resource| resource['id'] }
        expect(ids).to match_array([@u2.primary_key.to_s, @u3.primary_key.to_s])

        usernames = result['Resources'].map { |resource| resource['userName'] }
        expect(usernames).to match_array(['2', '3'])
      end
    end # "context 'with items' do"

    context 'with bad calls' do
      it 'complains about bad filters' do
        get '/Users', params: {
          format: :scim,
          filter: 'name.givenName'
        }

        expect(response.status                 ).to eql(400)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['scimType']).to eql('invalidFilter')
      end
    end # "context 'with bad calls' do"
  end # "context '#index' do"

  # ===========================================================================

  context '#show' do
    context 'with a UUID, renamed primary key column' do
      it 'shows an item' do
        expect_any_instance_of(MockUsersController).to receive(:show).once.and_call_original
        get "/Users/#{@u2.primary_key}", params: { format: :scim }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['id']).to eql(@u2.primary_key.to_s)
        expect(result['userName']).to eql('2')
        expect(result['name']['familyName']).to eql('Bar')
        expect(result['meta']['resourceType']).to eql('User')
      end
    end # "context 'with a UUID, renamed primary key column' do"

    context 'with an integer, conventionally named primary key column' do
      it 'shows an item' do
        expect_any_instance_of(MockGroupsController).to receive(:show).once.and_call_original
        get "/Groups/#{@g2.id}", params: { format: :scim }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['id']).to eql(@g2.id.to_s) # Note - ID was converted String; not Integer
        expect(result['displayName']).to eql('Group 2')
        expect(result['meta']['resourceType']).to eql('Group')
      end
    end # "context 'with an integer, conventionally named primary key column' do"

    it 'renders 404' do
      get '/Users/xyz', params: { format: :scim }

      expect(response.status                 ).to eql(404)
      expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

      result = JSON.parse(response.body)

      expect(result['status']).to eql('404')
    end
  end # "context '#show' do"

  # ===========================================================================

  context '#create' do
    context 'creates an item' do
      shared_examples 'a creator' do | force_upper_case: |
        it 'with minimal parameters' do
          mock_before = MockUser.all.to_a

          attributes = { userName: '4' } # Minimum required by schema
          attributes = spec_helper_hupcase(attributes) if force_upper_case

          # Prove that certain known pathways are called; can then unit test
          # those if need be and be sure that this covers #create actions.
          #
          expect_any_instance_of(MockUsersController).to receive(:create).once.and_call_original
          expect_any_instance_of(MockUsersController).to receive(:save! ).once.and_call_original

          expect {
            post "/Users", params: attributes.merge(format: :scim)
          }.to change { MockUser.count }.by(1)

          mock_after = MockUser.all.to_a
          new_mock = (mock_after - mock_before).first

          expect(response.status                 ).to eql(201)
          expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

          result = JSON.parse(response.body)

          expect(result['id']).to eql(new_mock.primary_key.to_s)
          expect(result['meta']['resourceType']).to eql('User')
          expect(new_mock.username).to eql('4')
        end

        # A bit of extra coverage just for general confidence.
        #
        it 'with more comprehensive parameters' do
          mock_before = MockUser.all.to_a

          attributes = {
            userName: '4',
            password: 'correcthorsebatterystaple',
            name: {
              givenName: 'Given',
              familyName: 'Family'
            },
            meta: { resourceType: 'User' },
            emails: [
              {
                type: 'work',
                value: 'work_4@test.com'
              },
              {
                type: 'home',
                value: 'home_4@test.com'
              }
            ]
          }

          attributes = spec_helper_hupcase(attributes) if force_upper_case

          expect {
            post "/Users", params: attributes.merge(format: :scim)
          }.to change { MockUser.count }.by(1)

          mock_after = MockUser.all.to_a
          new_mock = (mock_after - mock_before).first

          expect(response.status                 ).to eql(201)
          expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

          result = JSON.parse(response.body)

          expect(result['id']).to eql(new_mock.id.to_s)
          expect(result['meta']['resourceType']).to eql('User')
          expect(new_mock.username).to eql('4')
          expect(new_mock.password).to eql('correcthorsebatterystaple')
          expect(new_mock.first_name).to eql('Given')
          expect(new_mock.last_name).to eql('Family')
          expect(new_mock.home_email_address).to eql('home_4@test.com')
          expect(new_mock.work_email_address).to eql('work_4@test.com')
        end

        it 'with schema ID value keys without inline attributes' do
          mock_before = MockUser.all.to_a

          attributes = {
            userName: '4',
            'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User': {
              organization: 'Foo Bar!',
              department:   'Bar Foo!'
            },
            'urn:ietf:params:scim:schemas:extension:manager:1.0:User': {
              manager: 'Foo Baz!'
            }
          }

          attributes = spec_helper_hupcase(attributes) if force_upper_case

          expect {
            post "/Users", params: attributes.merge(format: :scim)
          }.to change { MockUser.count }.by(1)

          mock_after = MockUser.all.to_a
          new_mock = (mock_after - mock_before).first

          expect(response.status                 ).to eql(201)
          expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

          result = JSON.parse(response.body)

          expect(new_mock.organization).to eql('Foo Bar!')
          expect(new_mock.department  ).to eql('Bar Foo!')
          expect(new_mock.manager     ).to eql('Foo Baz!')

          expect(result['urn:ietf:params:scim:schemas:extension:enterprise:2.0:User']['organization']).to eql(new_mock.organization)
          expect(result['urn:ietf:params:scim:schemas:extension:enterprise:2.0:User']['department'  ]).to eql(new_mock.department  )
          expect(result['urn:ietf:params:scim:schemas:extension:manager:1.0:User'   ]['manager'     ]).to eql(new_mock.manager     )
        end

        it 'with schema ID value keys that have inline attributes' do
          mock_before = MockUser.all.to_a

          attributes = {
            userName: '4',
            'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:organization': 'Foo Bar!',
            'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:department':   'Bar Foo!',
            'urn:ietf:params:scim:schemas:extension:manager:1.0:User:manager':         'Foo Baz!'
          }

          attributes = spec_helper_hupcase(attributes) if force_upper_case

          expect {
            post "/Users", params: attributes.merge(format: :scim)
          }.to change { MockUser.count }.by(1)

          mock_after = MockUser.all.to_a
          new_mock = (mock_after - mock_before).first

          expect(response.status                 ).to eql(201)
          expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

          result = JSON.parse(response.body)

          expect(new_mock.organization).to eql('Foo Bar!')
          expect(new_mock.department  ).to eql('Bar Foo!')
          expect(new_mock.manager     ).to eql('Foo Baz!')

          expect(result['urn:ietf:params:scim:schemas:extension:enterprise:2.0:User']['organization']).to eql(new_mock.organization)
          expect(result['urn:ietf:params:scim:schemas:extension:enterprise:2.0:User']['department'  ]).to eql(new_mock.department  )
          expect(result['urn:ietf:params:scim:schemas:extension:manager:1.0:User'   ]['manager'     ]).to eql(new_mock.manager     )
        end
      end # "shared_examples 'a creator' do | force_upper_case: |"

      context 'using schema-matched case' do
        it_behaves_like 'a creator', force_upper_case: false
      end # "context 'using schema-matched case' do"

      context 'using upper case' do
        it_behaves_like 'a creator', force_upper_case: true
      end # "context 'using upper case' do"
    end

    it 'returns 409 for duplicates (by Rails validation)' do
      expect_any_instance_of(MockUsersController).to receive(:create).once.and_call_original
      expect {
        post "/Users", params: {
          format: :scim,
          userName: '1' # Already exists
        }
      }.to_not change { MockUser.count }

      expect(response.status                 ).to eql(409)
      expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

      result = JSON.parse(response.body)

      expect(result['scimType']).to eql('uniqueness')
      expect(result['detail']).to include('already been taken')
    end

    it 'notes schema validation failures' do
      expect {
        post "/Users", params: {
          format: :scim
          # userName parameter is required by schema, but missing
        }
      }.to_not change { MockUser.count }

      expect(response.status                 ).to eql(400)
      expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

      result = JSON.parse(response.body)

      expect(result['scimType']).to eql('invalidValue')
      expect(result['detail']).to include('is required')
    end

    it 'notes Rails validation failures' do
      expect {
        post "/Users", params: {
          format: :scim,
          userName: MockUser::INVALID_USERNAME
        }
      }.to_not change { MockUser.count }

      expect(response.status                 ).to eql(400)
      expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

      result = JSON.parse(response.body)

      expect(result['scimType']).to eql('invalidValue')
      expect(result['detail']).to include('is reserved')
    end

    context 'with a block' do
      it 'invokes the block' do
        mock_before = MockUser.all.to_a

        expect_any_instance_of(CustomCreateMockUsersController).to receive(:create).once.and_call_original
        expect {
          post "/CustomCreateUsers", params: {
            format:   :scim,
            userName: '4' # Minimum required by schema
          }
        }.to change { MockUser.count }.by(1)

        mock_after = MockUser.all.to_a
        new_mock = (mock_after - mock_before).first

        expect(response.status                 ).to eql(201)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['id']).to eql(new_mock.id.to_s)
        expect(result['meta']['resourceType']).to eql('User')
        expect(new_mock.first_name).to eql(CustomCreateMockUsersController::OVERRIDDEN_NAME)
      end

      it 'returns 409 for duplicates (by Rails validation)' do
        existing_user = MockUser.create!(
          username:           '4',
          first_name:         'Will Be Overridden',
          last_name:          'Baz',
          home_email_address: 'random@test.com',
          scim_uid:           '999'
        )

        expect_any_instance_of(CustomCreateMockUsersController).to receive(:create).once.and_call_original
        expect {
          post "/CustomCreateUsers", params: {
            format:   :scim,
            userName: '4' # Already exists
          }
        }.to_not change { MockUser.count }

        expect(response.status                 ).to eql(409)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['scimType']).to eql('uniqueness')
        expect(result['detail']).to include('already been taken')
      end

      it 'notes Rails validation failures' do
        expect_any_instance_of(CustomCreateMockUsersController).to receive(:create).once.and_call_original
        expect {
          post "/CustomCreateUsers", params: {
            format:   :scim,
            userName: MockUser::INVALID_USERNAME
          }
        }.to_not change { MockUser.count }

        expect(response.status                 ).to eql(400)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['scimType']).to eql('invalidValue')
        expect(result['detail']).to include('is reserved')
      end
    end # "context 'with a block' do"
  end # "context '#create' do"

  # ===========================================================================

  context '#replace' do
    shared_examples 'a replacer' do | force_upper_case: |
      it 'which replaces all attributes in an instance' do
        attributes = { userName: '4' } # Minimum required by schema
        attributes = spec_helper_hupcase(attributes) if force_upper_case

        # Prove that certain known pathways are called; can then unit test
        # those if need be and be sure that this covers #replace actions.
        #
        expect_any_instance_of(MockUsersController).to receive(:replace).once.and_call_original
        expect_any_instance_of(MockUsersController).to receive(:save!  ).once.and_call_original
        expect {
          put "/Users/#{@u2.primary_key}", params: attributes.merge(format: :scim)
        }.to_not change { MockUser.count }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['id']).to eql(@u2.primary_key.to_s)
        expect(result['meta']['resourceType']).to eql('User')

        expect(result).to     have_key('name')
        expect(result).to_not have_key('password')

        @u2.reload

        expect(@u2.username).to eql('4')
        expect(@u2.first_name).to be_nil
        expect(@u2.last_name).to be_nil
        expect(@u2.home_email_address).to be_nil
        expect(@u2.password).to be_nil
      end

      it 'can replace passwords' do
        attributes = { userName: '4', password: 'correcthorsebatterystaple' }
        attributes = spec_helper_hupcase(attributes) if force_upper_case

        expect {
          put "/Users/#{@u2.primary_key}", params: attributes.merge(format: :scim)
        }.to_not change { MockUser.count }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['id']).to eql(@u2.primary_key.to_s)
        expect(result['meta']['resourceType']).to eql('User')

        expect(result).to     have_key('name')
        expect(result).to_not have_key('password')

        @u2.reload

        expect(@u2.username).to eql('4')
        expect(@u2.first_name).to be_nil
        expect(@u2.last_name).to be_nil
        expect(@u2.home_email_address).to be_nil
        expect(@u2.password).to eql('correcthorsebatterystaple')
      end
    end # "shared_examples 'a replacer' do | force_upper_case: |"

    context 'using schema-matched case' do
      it_behaves_like 'a replacer', force_upper_case: false
    end # "context 'using schema-matched case' do"

    context 'using upper case' do
      it_behaves_like 'a replacer', force_upper_case: true
    end # "context 'using upper case' do"

    it 'notes schema validation failures' do
      expect {
        put "/Users/#{@u2.primary_key}", params: {
          format: :scim
          # userName parameter is required by schema, but missing
        }
      }.to_not change { MockUser.count }

      expect(response.status                 ).to eql(400)
      expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

      result = JSON.parse(response.body)

      expect(result['scimType']).to eql('invalidValue')
      expect(result['detail']).to include('is required')

      @u2.reload

      expect(@u2.username).to eql('2')
      expect(@u2.first_name).to eql('Foo')
      expect(@u2.last_name).to eql('Bar')
      expect(@u2.home_email_address).to eql('home_2@test.com')
    end

    it 'notes Rails validation failures' do
      expect {
        put "/Users/#{@u2.primary_key}", params: {
          format: :scim,
          userName: MockUser::INVALID_USERNAME
        }
      }.to_not change { MockUser.count }

      expect(response.status                 ).to eql(400)
      expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

      result = JSON.parse(response.body)

      expect(result['scimType']).to eql('invalidValue')
      expect(result['detail']).to include('is reserved')

      @u2.reload

      expect(@u2.username).to eql('2')
      expect(@u2.first_name).to eql('Foo')
      expect(@u2.last_name).to eql('Bar')
      expect(@u2.home_email_address).to eql('home_2@test.com')
    end

    it 'returns 404 if ID is invalid' do
      expect {
        put '/Users/xyz', params: {
          format: :scim,
          userName: '4' # Minimum required by schema
        }
      }.to_not change { MockUser.count }

      expect(response.status                 ).to eql(404)
      expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

      result = JSON.parse(response.body)

      expect(result['status']).to eql('404')
    end

    context 'with a block' do
      it 'invokes the block' do
        attributes = { userName: '4' } # Minimum required by schema

        expect_any_instance_of(CustomReplaceMockUsersController).to receive(:replace).once.and_call_original
        expect {
          put "/CustomReplaceUsers/#{@u2.primary_key}", params: {
            format:   :scim,
            userName: '4'
          }
        }.to_not change { MockUser.count }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['id']).to eql(@u2.primary_key.to_s)
        expect(result['meta']['resourceType']).to eql('User')

        @u2.reload

        expect(@u2.username  ).to eql('4')
        expect(@u2.first_name).to eql(CustomReplaceMockUsersController::OVERRIDDEN_NAME)
      end

      it 'notes Rails validation failures' do
        expect_any_instance_of(CustomReplaceMockUsersController).to receive(:replace).once.and_call_original
        expect {
          put "/CustomReplaceUsers/#{@u2.primary_key}", params: {
            format:   :scim,
            userName: MockUser::INVALID_USERNAME
          }
        }.to_not change { MockUser.count }

        expect(response.status                 ).to eql(400)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['scimType']).to eql('invalidValue')
        expect(result['detail']).to include('is reserved')

        @u2.reload

        expect(@u2.username).to eql('2')
        expect(@u2.first_name).to eql('Foo')
        expect(@u2.last_name).to eql('Bar')
        expect(@u2.home_email_address).to eql('home_2@test.com')
      end
    end # "context 'with a block' do"
  end # "context '#replace' do"

  # ===========================================================================

  context '#update' do
    shared_examples 'an updater' do | force_upper_case: |
      it 'which patches regular attributes' do
        payload = {
          Operations: [
            {
              op: 'add',
              path: 'userName',
              value: '4'
            },
            {
              op: 'replace',
              path: 'emails[type eq "work"]',
              value: { type: 'work', value: 'work_4@test.com' }
            }
          ]
        }

        payload = spec_helper_hupcase(payload) if force_upper_case

        # Prove that certain known pathways are called; can then unit test
        # those if need be and be sure that this covers #update actions.
        #
        expect_any_instance_of(MockUsersController).to receive(:update).once.and_call_original
        expect_any_instance_of(MockUsersController).to receive(:save! ).once.and_call_original

        expect {
          patch "/Users/#{@u2.primary_key}", params: payload.merge(format: :scim)
        }.to_not change { MockUser.count }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['id']).to eql(@u2.primary_key.to_s)
        expect(result['meta']['resourceType']).to eql('User')

        expect(result).to     have_key('name')
        expect(result).to_not have_key('password')

        @u2.reload

        expect(@u2.username).to eql('4')
        expect(@u2.first_name).to eql('Foo')
        expect(@u2.last_name).to eql('Bar')
        expect(@u2.home_email_address).to eql('home_2@test.com')
        expect(@u2.work_email_address).to eql('work_4@test.com')
        expect(@u2.password).to eql('oldpassword')
      end

      context 'which' do
        shared_examples 'it handles not-to-spec in-value Azure/Entra dotted attribute paths' do | operation |
          it "and performs operation" do
            payload = {
              Operations: [
                {
                  op: 'add',
                  value: {
                    'name.givenName'  => 'Foo!',
                    'name.familyName' => 'Bar!',
                    'name.formatted'  => 'Foo! Bar!' # Unrecognised; should be ignored
                  },
                },
              ]
            }

            payload = spec_helper_hupcase(payload) if force_upper_case
            patch "/Users/#{@u2.primary_key}", params: payload.merge(format: :scim)

            expect(response.status                 ).to eql(200)
            expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

            @u2.reload
            result = JSON.parse(response.body)

            expect(@u2.first_name).to eql('Foo!')
            expect(@u2.last_name ).to eql('Bar!')
          end
        end

        it_behaves_like 'it handles not-to-spec in-value Azure/Entra dotted attribute paths', 'add'
        it_behaves_like 'it handles not-to-spec in-value Azure/Entra dotted attribute paths', 'replace'

        shared_examples 'it handles schema ID value keys without inline attributes' do | operation |
          it "and performs operation" do
            payload = {
              Operations: [
                {
                  op: operation,
                  value: {
                    'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User': {
                      'organization' => 'Foo Bar!',
                      'department'   => 'Bar Foo!'
                    },
                    'urn:ietf:params:scim:schemas:extension:manager:1.0:User': {
                      'manager' => 'Foo Baz!'
                    }
                  },
                },
              ]
            }

            @u2.update!(organization: 'Old org')
            payload = spec_helper_hupcase(payload) if force_upper_case
            patch "/Users/#{@u2.primary_key}", params: payload.merge(format: :scim)

            expect(response.status                 ).to eql(200)
            expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

            @u2.reload
            result = JSON.parse(response.body)

            expect(@u2.organization).to eql('Foo Bar!')
            expect(@u2.department  ).to eql('Bar Foo!')
            expect(@u2.manager     ).to eql('Foo Baz!')
          end
        end

        it_behaves_like 'it handles schema ID value keys without inline attributes', 'add'
        it_behaves_like 'it handles schema ID value keys without inline attributes', 'replace'

        shared_examples 'it handles schema ID value keys with inline attributes' do | operation |
          it "and performs operation" do
            payload = {
              Operations: [
                {
                  op: operation,
                  value: {
                    'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:organization' => 'Foo Bar!',
                    'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:department'   => 'Bar Foo!',
                    'urn:ietf:params:scim:schemas:extension:manager:1.0:User:manager'         => 'Foo Baz!'
                  },
                },
              ]
            }

            @u2.update!(organization: 'Old org')
            payload = spec_helper_hupcase(payload) if force_upper_case
            patch "/Users/#{@u2.primary_key}", params: payload.merge(format: :scim)

            expect(response.status                 ).to eql(200)
            expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

            @u2.reload
            result = JSON.parse(response.body)

            expect(@u2.organization).to eql('Foo Bar!')
            expect(@u2.department  ).to eql('Bar Foo!')
            expect(@u2.manager     ).to eql('Foo Baz!')
          end
        end

        it_behaves_like 'it handles schema ID value keys with inline attributes', 'add'
        it_behaves_like 'it handles schema ID value keys with inline attributes', 'replace'

        shared_examples 'it handles schema ID value keys of extension schema complex attributes via path' do | operation |
          around :each do | example |
            module ScimSchemaExtensions
              module User
                class EnterpisePositionSchema < Scimitar::Schema::Base
                  def self.scim_attributes
                    @scim_attributes ||= [
                      Scimitar::Schema::Attribute.new(name: 'organization', type: 'string'),
                      Scimitar::Schema::Attribute.new(name: 'department',   type: 'string'),
                    ]
                  end
                end

                class EnterpisePositionComplexType < Scimitar::ComplexTypes::Base
                  set_schema EnterpisePositionSchema
                end

                class EnterpiseManager < Scimitar::Schema::Base
                  def initialize(options = {})
                    super(
                      name:            'EnterpiseManager extension schema',
                      description:     'EnterpiseManager extension for a Enterprise User',
                      id:              self.class.id,
                      scim_attributes: self.class.scim_attributes
                    )
                  end

                  def self.id
                    'urn:ietf:params:scim:schemas:extension:enterprise_manager:1.0:User'
                  end

                  def self.scim_attributes
                    [
                      Scimitar::Schema::Attribute.new(name: "position", complexType: EnterpisePositionComplexType),
                    ]
                  end
                end
              end
            end

            # change SCIM attributes map temporarily
            class << MockUser
              alias_method :original_scim_attributes_map, :scim_attributes_map

              def scim_attributes_map
                map = original_scim_attributes_map.merge(
                  position: {
                    organization: :organization,
                    department:   :department,
                  }
                )
                map.delete(:organization)
                map.delete(:department)
                map
              end
            end

            # change extension schemas on User temporarily
            @original_extended_schemas = Scimitar::Resources::User.extended_schemas
            Scimitar::Resources::User.instance_variable_set(:@extended_schemas, [])
            Scimitar::Resources::User.extend_schema ScimSchemaExtensions::User::EnterpiseManager

            example.run()
          ensure
            # restore original setup
            Scimitar::Resources::User.instance_variable_set(:@extended_schemas, @original_extended_schemas)

            class << MockUser
              alias_method :scim_attributes_map, :original_scim_attributes_map
              remove_method :original_scim_attributes_map
            end
          end

          it "and performs operation" do
            payload = {
              Operations: [
                {
                  op: operation,
                  path: 'urn:ietf:params:scim:schemas:extension:enterprise_manager:1.0:User:position',
                  value: {
                    'organization' => 'Foo Bar!',
                    'department'   => 'Bar Foo!'
                  },
                },
              ]
            }

            @u2.update!(organization: 'Old org')
            payload = spec_helper_hupcase(payload) if force_upper_case
            patch "/Users/#{@u2.primary_key}", params: payload.merge(format: :scim)

            expect(response.status                 ).to eql(200)
            expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

            @u2.reload

            expect(@u2.organization).to eql('Foo Bar!')
            expect(@u2.department  ).to eql('Bar Foo!')
          end
        end

        it_behaves_like 'it handles schema ID value keys of extension schema complex attributes via path', 'add'
        it_behaves_like 'it handles schema ID value keys of extension schema complex attributes via path', 'replace'
      end

      it 'which patches "returned: \'never\'" fields' do
        payload = {
          Operations: [
            {
              op: 'replace',
              path: 'password',
              value: 'correcthorsebatterystaple'
            }
          ]
        }

        payload = spec_helper_hupcase(payload) if force_upper_case

        expect {
          patch "/Users/#{@u2.primary_key}", params: payload.merge(format: :scim)
        }.to_not change { MockUser.count }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['id']).to eql(@u2.primary_key.to_s)
        expect(result['meta']['resourceType']).to eql('User')

        expect(result).to     have_key('name')
        expect(result).to_not have_key('password')

        @u2.reload

        expect(@u2.username).to eql('2')
        expect(@u2.first_name).to eql('Foo')
        expect(@u2.last_name).to eql('Bar')
        expect(@u2.home_email_address).to eql('home_2@test.com')
        expect(@u2.work_email_address).to be_nil
        expect(@u2.password).to eql('correcthorsebatterystaple')
      end

      context 'which clears attributes' do
        before :each do
          @u2.update!(work_email_address: 'work_2@test.com')
        end

        it 'with simple paths' do
          payload = {
            Operations: [
              {
                op: 'remove',
                path: 'name.givenName'
              }
            ]
          }

          payload = spec_helper_hupcase(payload) if force_upper_case

          expect_any_instance_of(MockUsersController).to receive(:update).once.and_call_original
          expect {
            patch "/Users/#{@u2.primary_key}", params: payload.merge(format: :scim)
          }.to_not change { MockUser.count }

          expect(response.status                 ).to eql(200)
          expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

          result = JSON.parse(response.body)

          expect(result['id']).to eql(@u2.primary_key.to_s)
          expect(result['meta']['resourceType']).to eql('User')

          @u2.reload

          expect(@u2.username).to eql('2')
          expect(@u2.first_name).to be_nil
          expect(@u2.last_name).to eql('Bar')
          expect(@u2.home_email_address).to eql('home_2@test.com')
          expect(@u2.work_email_address).to eql('work_2@test.com')
        end

        it 'by array entry filter match' do
          payload = {
            Operations: [
              {
                op: 'remove',
                path: 'emails[type eq "work"]'
              }
            ]
          }

          payload = spec_helper_hupcase(payload) if force_upper_case

          expect_any_instance_of(MockUsersController).to receive(:update).once.and_call_original
          expect {
            patch "/Users/#{@u2.primary_key}", params: payload.merge(format: :scim)
          }.to_not change { MockUser.count }

          expect(response.status                 ).to eql(200)
          expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

          result = JSON.parse(response.body)

          expect(result['id']).to eql(@u2.primary_key.to_s)
          expect(result['meta']['resourceType']).to eql('User')

          @u2.reload

          expect(@u2.username).to eql('2')
          expect(@u2.first_name).to eql('Foo')
          expect(@u2.last_name).to eql('Bar')
          expect(@u2.home_email_address).to eql('home_2@test.com')
          expect(@u2.work_email_address).to be_nil
        end

        it 'by whole collection' do
          payload = {
            Operations: [
              {
                op: 'remove',
                path: 'emails'
              }
            ]
          }

          payload = spec_helper_hupcase(payload) if force_upper_case

          expect_any_instance_of(MockUsersController).to receive(:update).once.and_call_original
          expect {
            patch "/Users/#{@u2.primary_key}", params: payload.merge(format: :scim)
          }.to_not change { MockUser.count }

          expect(response.status                 ).to eql(200)
          expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

          result = JSON.parse(response.body)

          expect(result['id']).to eql(@u2.primary_key.to_s)
          expect(result['meta']['resourceType']).to eql('User')

          @u2.reload

          expect(@u2.username).to eql('2')
          expect(@u2.first_name).to eql('Foo')
          expect(@u2.last_name).to eql('Bar')
          expect(@u2.home_email_address).to be_nil
          expect(@u2.work_email_address).to be_nil
        end
      end # "context 'which clears attributes' do"
    end # "shared_examples 'an updater' do | force_upper_case: |"

    context 'using schema-matched case' do
      it_behaves_like 'an updater', force_upper_case: false
    end # "context 'using schema-matched case' do"

    context 'using upper case' do
      it_behaves_like 'an updater', force_upper_case: true
    end # "context 'using upper case' do"

    it 'notes Rails validation failures' do
      expect {
        patch "/Users/#{@u2.primary_key}", params: {
          format: :scim,
          Operations: [
            {
              op: 'add',
              path: 'userName',
              value: MockUser::INVALID_USERNAME
            }
          ]
        }
      }.to_not change { MockUser.count }

      expect(response.status                 ).to eql(400)
      expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

      result = JSON.parse(response.body)

      expect(result['scimType']).to eql('invalidValue')
      expect(result['detail']).to include('is reserved')

      @u2.reload

      expect(@u2.username).to eql('2')
      expect(@u2.first_name).to eql('Foo')
      expect(@u2.last_name).to eql('Bar')
      expect(@u2.home_email_address).to eql('home_2@test.com')
    end

    it 'returns 404 if ID is invalid' do
      expect {
        patch '/Users/xyz', params: {
          format: :scim,
          Operations: [
            {
              op: 'add',
              path: 'userName',
              value: '4'
            }
          ]
        }
      }.to_not change { MockUser.count }

      expect(response.status                 ).to eql(404)
      expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

      result = JSON.parse(response.body)

      expect(result['status']).to eql('404')
    end

    context 'when removing users from groups' do
      before :each do
        @g1.mock_users << @u1
        @g1.mock_users << @u2
        @g1.mock_users << @u3

        # (Self-check) Verify group representation
        #
        get "/Groups/#{@g1.id}", params: { format: :scim }

        expect(response.status).to eql(200)
        result = JSON.parse(response.body)

        expect(result['members'].map { |m| m['value'] }.sort()).to eql(MockUser.pluck(:primary_key).sort())
      end

      it 'can remove all users' do
        expect {
          expect {
            patch "/Groups/#{@g1.id}", params: {
              format: :scim,
              Operations: [
                {
                  op: 'remove',
                  path: 'members'
                }
              ]
            }
          }.to_not change { MockUser.count }
        }.to_not change { MockGroup.count }

        get "/Groups/#{@g1.id}", params: { format: :scim }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['members']).to be_empty
        expect(@g1.reload().mock_users).to be_empty
      end

      # Define via 'let':
      #
      # * Hash 'payload', to send via 'patch'
      # * MockUser 'removed_user', which is the user that should be removed
      #
      shared_examples 'a user remover' do
        it 'which removes the identified user' do
          expect {
            expect {
              patch "/Groups/#{@g1.id}", params: payload()
            }.to_not change { MockUser.count }
          }.to_not change { MockGroup.count }

          expected_remaining_user_ids = MockUser
            .where.not(primary_key: removed_user().id)
            .pluck(:primary_key)
            .sort()

          get "/Groups/#{@g1.id}", params: { format: :scim }

          expect(response.status                 ).to eql(200)
          expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

          result = JSON.parse(response.body)

          expect(result['members'].map { |m| m['value'] }.sort()).to eql(expected_remaining_user_ids)
          expect(@g1.reload().mock_users.map(&:primary_key).sort()).to eql(expected_remaining_user_ids)
        end
      end

      # https://tools.ietf.org/html/rfc7644#section-3.5.2.2
      #
      context 'and using an RFC-compliant payload' do
        let(:removed_user) { @u2 }
        let(:payload) do
          {
            format: :scim,
            Operations: [
              {
                op: 'remove',
                path: "members[value eq \"#{removed_user().primary_key}\"]",
              }
            ]
          }
        end

        it_behaves_like 'a user remover'
      end # context 'and using an RFC-compliant payload' do

      # https://learn.microsoft.com/en-us/azure/active-directory/app-provisioning/use-scim-to-provision-users-and-groups#update-group-remove-members
      #
      context 'and using a Microsoft variant payload' do
        let(:removed_user) { @u2 }
        let(:payload) do
          {
            format: :scim,
            Operations: [
              {
                op: 'remove',
                path: 'members',
                value: [{
                  '$ref' => nil,
                  'value' => removed_user().primary_key
                }]
              }
            ]
          }
        end

        it_behaves_like 'a user remover'
      end # context 'and using a Microsoft variant payload' do

      # https://help.salesforce.com/s/articleView?id=sf.identity_scim_manage_groups.htm&type=5
      #
      context 'and using a Salesforce variant payload' do
        let(:removed_user) { @u2 }
        let(:payload) do
          {
            format: :scim,
            Operations: [
              {
                op: 'remove',
                path: 'members',
                value: {
                  'members' => [{
                    '$ref' => nil,
                    'value' => removed_user().primary_key
                  }]
                }
              }
            ]
          }
        end

        it_behaves_like 'a user remover'
      end # context 'and using a Salesforce variant payload' do
    end # "context 'when removing users from groups' do"

    context 'with a block' do
      it 'invokes the block' do
        payload = {
          format: :scim,
          Operations: [
            {
              op: 'add',
              path: 'userName',
              value: '4'
            },
            {
              op: 'replace',
              path: 'emails[type eq "work"]',
              value: { type: 'work', value: 'work_4@test.com' }
            }
          ]
        }

        expect_any_instance_of(CustomUpdateMockUsersController).to receive(:update).once.and_call_original
        expect {
          patch "/CustomUpdateUsers/#{@u2.primary_key}", params: payload
        }.to_not change { MockUser.count }

        expect(response.status                 ).to eql(200)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['id']).to eql(@u2.primary_key.to_s)
        expect(result['meta']['resourceType']).to eql('User')

        @u2.reload

        expect(@u2.username          ).to eql('4')
        expect(@u2.first_name        ).to eql(CustomUpdateMockUsersController::OVERRIDDEN_NAME)
        expect(@u2.work_email_address).to eql('work_4@test.com')
      end

      it 'notes Rails validation failures' do
        expect_any_instance_of(CustomUpdateMockUsersController).to receive(:update).once.and_call_original
        expect {
          patch "/CustomUpdateUsers/#{@u2.primary_key}", params: {
            format: :scim,
            Operations: [
              {
                op: 'add',
                path: 'userName',
                value: MockUser::INVALID_USERNAME
              }
            ]
          }
        }.to_not change { MockUser.count }

        expect(response.status                 ).to eql(400)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        expect(result['scimType']).to eql('invalidValue')
        expect(result['detail']).to include('is reserved')

        @u2.reload

        expect(@u2.username).to eql('2')
        expect(@u2.first_name).to eql('Foo')
        expect(@u2.last_name).to eql('Bar')
        expect(@u2.home_email_address).to eql('home_2@test.com')
      end
    end # "context 'with a block' do"
  end # "context '#update' do"

  # ===========================================================================
  # In-passing parts of tests above show that #create, #replace and #update all
  # route through #save!, so now add some unit tests for that and for exception
  # handling overrides invoked via #save!.
  # ===========================================================================

  context 'overriding #save!' do
    it 'invokes a block if given one' do
      mock_before = MockUser.all.to_a
      attributes = { userName: '5' } # Minimum required by schema

      expect_any_instance_of(CustomSaveMockUsersController).to receive(:create).once.and_call_original
      expect {
        post "/CustomSaveUsers", params: attributes.merge(format: :scim)
      }.to change { MockUser.count }.by(1)

      mock_after = MockUser.all.to_a
      new_mock = (mock_after - mock_before).first

      expect(response.status                 ).to eql(201)
      expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

      expect(new_mock.username).to eql(CustomSaveMockUsersController::CUSTOM_SAVE_BLOCK_USERNAME_INDICATOR)
    end
  end # "context 'overriding #save!' do

  context 'custom on-save exceptions' do
    MockUsersController.new.send(:scimitar_rescuable_exceptions).each do | exception_class |
      it "handles out-of-box exception #{exception_class}" do
        expect_any_instance_of(MockUsersController).to receive(:create).once.and_call_original
        expect_any_instance_of(MockUsersController).to receive(:save! ).once.and_call_original

        expect_any_instance_of(MockUser).to receive(:save!).once { raise exception_class }

        expect {
          post "/Users", params: { format: :scim, userName: SecureRandom.uuid }
        }.to_not change { MockUser.count }

        expected_status, expected_prefix = if exception_class == ActiveRecord::RecordNotUnique
          [409, 'Operation failed due to a uniqueness constraint: ']
        else
          [400, 'Operation failed since record has become invalid: ']
        end

        expect(response.status                 ).to eql(expected_status)
        expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

        result = JSON.parse(response.body)

        # Check basic SCIM error rendering - good enough given other tests
        # elsewhere. Exact message varies by exception.
        #
        expect(result['detail']).to start_with(expected_prefix)
      end
    end

    it 'handles custom exceptions' do
      exception_class = RuntimeError # (for testing only; usually, this would provoke a 500 response)

      expect_any_instance_of(MockUsersController).to receive(:create).once.and_call_original
      expect_any_instance_of(MockUsersController).to receive(:save! ).once.and_call_original

      expect_any_instance_of(MockUsersController).to receive(:scimitar_rescuable_exceptions).once { [ exception_class ] }
      expect_any_instance_of(MockUser           ).to receive(:save!                        ).once { raise exception_class }

      expect {
        post "/Users", params: { format: :scim, userName: SecureRandom.uuid }
      }.to_not change { MockUser.count }

      expect(response.status                 ).to eql(400)
      expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

      result = JSON.parse(response.body)

      expect(result['detail']).to start_with('Operation failed since record has become invalid: ')
    end

    it 'reports other exceptions as 500s' do
      expect_any_instance_of(MockUsersController).to receive(:create).once.and_call_original
      expect_any_instance_of(MockUsersController).to receive(:save! ).once.and_call_original

      expect_any_instance_of(MockUser).to receive(:save!).once { raise RuntimeError }

      expect {
        post "/Users", params: { format: :scim, userName: SecureRandom.uuid }
      }.to_not change { MockUser.count }

      expect(response.status                 ).to eql(500)
      expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

      result = JSON.parse(response.body)

      expect(result['detail']).to eql('RuntimeError')
    end
  end

  # ===========================================================================

  context '#destroy' do
    it 'deletes an item if given no block' do
      expect_any_instance_of(MockUsersController).to receive(:destroy).once.and_call_original
      expect_any_instance_of(MockUser).to receive(:destroy!).once.and_call_original
      expect {
        delete "/Users/#{@u2.primary_key}", params: { format: :scim }
      }.to change { MockUser.count }.by(-1)

      expect(response.status).to eql(204)
      expect(response.body).to be_empty
    end

    it 'invokes a block if given one' do
      expect_any_instance_of(CustomDestroyMockUsersController).to receive(:destroy).once.and_call_original
      expect_any_instance_of(MockUser).to_not receive(:destroy!)

      expect {
        delete "/CustomDestroyUsers/#{@u2.primary_key}", params: { format: :scim }
      }.to_not change { MockUser.count }

      expect(response.status).to eql(204)
      expect(response.body).to be_empty

      @u2.reload
      expect(@u2.username).to eql(CustomDestroyMockUsersController::NOT_REALLY_DELETED_USERNAME_INDICATOR)
    end

    it 'returns 404 if ID is invalid' do
      expect {
        delete '/Users/xyz', params: { format: :scim }
      }.to_not change { MockUser.count }

      expect(response.status                 ).to eql(404)
      expect(response.headers['Content-Type']).to eql('application/scim+json; charset=utf-8')

      result = JSON.parse(response.body)

      expect(result['status']).to eql('404')
    end
  end # "context '#destroy' do"

  # ===========================================================================

  context 'service methods' do
    context '#storage_scope' do
      it 'raises "not implemented" to warn subclass authors' do
        expect { described_class.new.send(:storage_scope) }.to raise_error(NotImplementedError)
      end
    end # "context '#storage_class' do"
  end # "context 'service methods' do"
end
