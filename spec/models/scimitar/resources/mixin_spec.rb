require 'spec_helper'

RSpec.describe Scimitar::Resources::Mixin do

  # ===========================================================================
  # Internal classes used in some tests
  # ===========================================================================

  class StaticMapTest
    include ActiveModel::Model

    attr_accessor :work_email_address,
                  :home_email_address

    def self.scim_resource_type
      return Scimitar::Resources::User
    end

    def self.scim_attributes_map
      return {
        emails: [
          {
            match: 'type',
            with:  'work',
            using: {
              value:   :work_email_address,
              primary: false
            }
          },
          {
            match: 'type',
            with:  'home',
            using: { value: :home_email_address }
          }
        ]
      }
    end

    def self.scim_mutable_attributes
      return nil
    end

    def self.scim_queryable_attributes
      return nil
    end

    include Scimitar::Resources::Mixin
  end

  class DynamicMapTest
    include ActiveModel::Model

    attr_accessor :groups

    def self.scim_resource_type
      return Scimitar::Resources::User
    end

    def self.scim_attributes_map
      return {
        groups: [
          {
            list:  :groups,
            using: {
              value:   :id,        # <-- i.e. DynamicMapTest.groups[n].id
              display: :full_name  # <-- i.e. DynamicMapTest.groups[n].full_name
            }
          }
        ]
      }
    end

    def self.scim_mutable_attributes
      return nil
    end

    def self.scim_queryable_attributes
      return nil
    end

    include Scimitar::Resources::Mixin
  end

  # A simple schema containing two attributes that looks very like complex
  # type "name", except shorter and with "familyName" never returned.
  #
  NestedReturnedNeverTestNameSchema = Class.new(Scimitar::Schema::Base) do
    def self.id
      'nested-returned-never-name-id'
    end

    def self.scim_attributes
      @scim_attributes ||= [
        Scimitar::Schema::Attribute.new(name: 'familyName', type: 'string', required: true, returned: 'never'),
        Scimitar::Schema::Attribute.new(name: 'givenName',  type: 'string', required: true)
      ]
    end
  end

  # A complex type that uses the above schema, giving us the ability to define
  # an attribute using this complex type, with therefore the *nested* attribute
  # "familyName" being never returned.
  #
  NestedReturnedNeverTestNameType = Class.new(Scimitar::ComplexTypes::Base) do
    set_schema NestedReturnedNeverTestNameSchema
  end

  # A test schema that uses the above type, the standard name type (but that
  # *entire* top-level attribute is never returned) and a simple String item.
  #
  NestedReturnedNeverTestSchema = Class.new(Scimitar::Schema::Base) do
    def self.id
      'nested-returned-never-id'
    end

    def self.scim_attributes
      [
        Scimitar::Schema::Attribute.new(
          name: 'name', complexType: NestedReturnedNeverTestNameType
        ),
        Scimitar::Schema::Attribute.new(
          name: 'privateName', complexType: Scimitar::ComplexTypes::Name, returned: 'never'
        ),
        Scimitar::Schema::Attribute.new(
          name: 'simpleName',  type: 'string'
        )
      ]
    end
  end

  # Define a resource that is based upon the above schema.
  #
  NestedReturnedNeverTestResourse = Class.new(Scimitar::Resources::Base) do
    set_schema NestedReturnedNeverTestSchema
  end

  # Create a testable model that is our internal representation of the above
  # resource.
  #
  class NestedReturnedNeverTest
    include ActiveModel::Model

    def self.scim_resource_type
      return NestedReturnedNeverTestResourse
    end

    attr_accessor :given_name,
                  :last_name,
                  :private_given_name,
                  :private_last_name,
                  :simple_name

    def self.scim_attributes_map
      return {
        name: {
          givenName:  :given_name,
          familyName: :last_name
        },

        privateName: {
          givenName:  :private_given_name,
          familyName: :private_last_name
        },

        simpleName: :simple_name
      }
    end

    def self.scim_mutable_attributes
      return nil
    end

    def self.scim_queryable_attributes
      return nil
    end

    include Scimitar::Resources::Mixin
  end

  # ===========================================================================
  # Errant class definitions
  # ===========================================================================

  context 'with bad class definitions' do
    it 'complains about missing mandatory methods' do
      mandatory_class_methods = %w{
        scim_resource_type
        scim_attributes_map
        scim_mutable_attributes
        scim_queryable_attributes
      }

      mandatory_class_methods.each do | required_class_method |

        # E.g. "You must define ::scim_resource_type in #<Class:...>"
        #
        expect {
          klass = Class.new(BasicObject) do
            fewer_class_methods = mandatory_class_methods - [required_class_method]
            fewer_class_methods.each do | method_to_define |
              define_singleton_method(method_to_define) do
                puts 'I am defined'
              end
            end

            include Scimitar::Resources::Mixin
          end
        }.to raise_error(RuntimeError, /#{Regexp.escape(required_class_method)}/)
      end
    end
  end # "context 'with bad class definitions' do"

  # ===========================================================================
  # Correct class definitions
  # ===========================================================================

  context 'with good class definitons' do

    require_relative '../../../apps/dummy/app/models/mock_user.rb'
    require_relative '../../../apps/dummy/app/models/mock_group.rb'

    # =========================================================================
    # Support methods
    # =========================================================================

    context '#scim_queryable_attributes' do
      it 'exposes queryable attributes as an instance method' do
        instance_result = MockUser.new.scim_queryable_attributes()
        class_result    = MockUser.scim_queryable_attributes()

        expect(instance_result).to match_array(class_result)
      end
    end # "context '#scim_queryable_attributes' do"

    context '#scim_mutable_attributes' do
      it 'self-compiles mutable attributes and exposes them as an instance method' do
        readwrite_attrs = MockUser::READWRITE_ATTRS.map(&:to_sym)
        readwrite_attrs.delete(:id) # Should never be offered as writable in SCIM

        result = MockUser.new.scim_mutable_attributes()
        expect(result).to match_array(readwrite_attrs)
      end

      it 'includes read-write dynamic list attributes' do
        readwrite_attrs = MockGroup::READWRITE_ATTRS.map(&:to_sym)
        readwrite_attrs.delete(:id) # Should never be offered as writable in SCIM

        result = MockGroup.new.scim_mutable_attributes()
        expect(result).to match_array(readwrite_attrs)
      end
    end # "context '#scim_mutable_attributes' do"

    # =========================================================================
    # #to_scim
    # =========================================================================

    context '#to_scim' do
      context 'with list of requested attributes' do
        it 'compiles instance attribute values into a SCIM representation, including only the requested attributes' do
          uuid                        = SecureRandom.uuid

          instance                    = MockUser.new
          instance.primary_key        = uuid
          instance.scim_uid           = 'AA02984'
          instance.username           = 'foo'
          instance.password           = 'correcthorsebatterystaple'
          instance.first_name         = 'Foo'
          instance.last_name          = 'Bar'
          instance.work_email_address = 'foo.bar@test.com'
          instance.home_email_address = 'foo.bar@example.com'
          instance.work_phone_number  = '+642201234567'
          instance.organization       = 'SOMEORG'

          g1 = MockGroup.create!(display_name: 'Group 1')
          g2 = MockGroup.create!(display_name: 'Group 2')
          g3 = MockGroup.create!(display_name: 'Group 3')

          g1.mock_users << instance
          g3.mock_users << instance

          scim = instance.to_scim(location: "https://test.com/mock_users/#{uuid}", include_attributes: %w[id userName name groups.display groups.value organization])
          json = scim.to_json()
          hash = JSON.parse(json)

          expect(hash).to eql({
            'id'          => uuid,
            'userName'    => 'foo',
            'name'        => {'givenName'=>'Foo', 'familyName'=>'Bar'},
            'groups'      => [{'display'=>g1.display_name, 'value'=>g1.id.to_s}, {'display'=>g3.display_name, 'value'=>g3.id.to_s}],
            'meta'        => {'location'=>"https://test.com/mock_users/#{uuid}", 'resourceType'=>'User'},
            'schemas'     => [
              'urn:ietf:params:scim:schemas:core:2.0:User',
              'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User',
              'urn:ietf:params:scim:schemas:extension:manager:1.0:User',
            ],
            'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User' => {
              'organization' => 'SOMEORG',
            },
            'urn:ietf:params:scim:schemas:extension:manager:1.0:User' => {},
          })
        end

        it 'hides "nil" value attributes' do
          uuid                        = SecureRandom.uuid

          instance                    = MockUser.new
          instance.primary_key        = uuid
          instance.scim_uid           = 'AA02984'
          instance.username           = nil
          instance.password           = 'correcthorsebatterystaple'
          instance.first_name         = nil
          instance.last_name          = 'Bar'
          instance.work_email_address = 'foo.bar@test.com'
          instance.home_email_address = 'foo.bar@example.com'
          instance.work_phone_number  = '+642201234567'
          instance.organization       = 'SOMEORG'

          g1 = MockGroup.create!(display_name: 'Group 1')
          g2 = MockGroup.create!(display_name: 'Group 2')
          g3 = MockGroup.create!(display_name: 'Group 3')

          g1.mock_users << instance
          g3.mock_users << instance

          scim = instance.to_scim(location: "https://test.com/mock_users/#{uuid}", include_attributes: %w[id userName name groups.display groups.value organization])
          json = scim.to_json()
          hash = JSON.parse(json)

          expect(hash).to eql({
            'id'          => uuid,
            'name'        => {'familyName'=>'Bar'},
            'groups'      => [{'display'=>g1.display_name, 'value'=>g1.id.to_s}, {'display'=>g3.display_name, 'value'=>g3.id.to_s}],
            'meta'        => {'location'=>"https://test.com/mock_users/#{uuid}", 'resourceType'=>'User'},
            'schemas'     => [
              'urn:ietf:params:scim:schemas:core:2.0:User',
              'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User',
              'urn:ietf:params:scim:schemas:extension:manager:1.0:User',
            ],
            'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User' => {
              'organization' => 'SOMEORG',
            },
            'urn:ietf:params:scim:schemas:extension:manager:1.0:User' => {},
          })
        end
      end # "context 'with list of requested attributes' do"

      context 'with a UUID, renamed primary key column' do
        it 'compiles instance attribute values into a SCIM representation, but omits do-not-return fields' do
          uuid                        = SecureRandom.uuid

          instance                    = MockUser.new
          instance.primary_key        = uuid
          instance.scim_uid           = 'AA02984'
          instance.username           = 'foo'
          instance.password           = 'correcthorsebatterystaple'
          instance.first_name         = 'Foo'
          instance.last_name          = 'Bar'
          instance.work_email_address = 'foo.bar@test.com'
          instance.home_email_address = nil
          instance.work_phone_number  = '+642201234567'
          instance.organization       = 'SOMEORG'

          g1 = MockGroup.create!(display_name: 'Group 1')
          g2 = MockGroup.create!(display_name: 'Group 2')
          g3 = MockGroup.create!(display_name: 'Group 3')

          g1.mock_users << instance
          g3.mock_users << instance

          scim = instance.to_scim(location: "https://test.com/mock_users/#{uuid}")
          json = scim.to_json()
          hash = JSON.parse(json)

          expect(hash).to eql({
            'userName'    => 'foo',
            'name'        => {'givenName'=>'Foo', 'familyName'=>'Bar'},
            'active'      => true,
            'emails'      => [{'type'=>'work', 'primary'=>true, 'value'=>'foo.bar@test.com'}, {'primary'=>false, 'type'=>'home', 'value'=>nil}],
            'phoneNumbers'=> [{'type'=>'work', 'primary'=>false, 'value'=>'+642201234567'}],
            'id'          => uuid,
            'externalId'  => 'AA02984',
            'groups'      => [{'display'=>g1.display_name, 'value'=>g1.id.to_s}, {'display'=>g3.display_name, 'value'=>g3.id.to_s}],
            'meta'        => {'location'=>"https://test.com/mock_users/#{uuid}", 'resourceType'=>'User'},
            'schemas'     => [
              'urn:ietf:params:scim:schemas:core:2.0:User',
              'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User',
              'urn:ietf:params:scim:schemas:extension:manager:1.0:User',
            ],
            'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User' => {
              'organization' => 'SOMEORG',
              'department'   => nil,
              'primaryEmail' => instance.work_email_address,
            },
            'urn:ietf:params:scim:schemas:extension:manager:1.0:User' => {
              'manager' => nil
            },
          })
        end

        context 'and when configured to omit "nil" values in the response' do
          around :each do | example |
            original_configuration = Scimitar.engine_configuration.render_mapped_nil_values_in_response
            Scimitar.engine_configuration.render_mapped_nil_values_in_response = false
            example.run()
          ensure
            Scimitar.engine_configuration.render_mapped_nil_values_in_response = original_configuration
          end

          it 'omits "nil" values as expected' do
            uuid                        = SecureRandom.uuid

            instance                    = MockUser.new
            instance.primary_key        = uuid
            instance.scim_uid           = 'AA02984'
            instance.username           = 'foo'
            instance.password           = 'correcthorsebatterystaple'
            instance.first_name         = nil
            instance.last_name          = 'Bar'
            instance.work_email_address = 'foo.bar@test.com'
            instance.home_email_address = nil
            instance.work_phone_number  = '+642201234567'
            instance.organization       = 'SOMEORG'

            g1 = MockGroup.create!(display_name: 'Group 1')
            g2 = MockGroup.create!(display_name: 'Group 2')
            g3 = MockGroup.create!(display_name: 'Group 3')

            g1.mock_users << instance
            g3.mock_users << instance

            scim = instance.to_scim(location: "https://test.com/mock_users/#{uuid}")
            json = scim.to_json()
            hash = JSON.parse(json)

            # Note currently limited implementation for things like static maps,
            # where part of the returned value is included; in this case, the
            # "primary" value is "false" for e-mail of type "home", so the
            # structure for that *does* appear in the output array even though
            # the source dynamic data field from the NockUser instance is "nil".
            #
            expect(hash).to eql({
              'userName'    => 'foo',
              'name'        => {'familyName'=>'Bar'},
              'active'      => true,
              'emails'      => [{'type'=>'work', 'primary'=>true, 'value'=>'foo.bar@test.com'}, {'primary' => false, 'type' => 'home'}],
              'phoneNumbers'=> [{'type'=>'work', 'primary'=>false, 'value'=>'+642201234567'}],
              'id'          => uuid,
              'externalId'  => 'AA02984',
              'groups'      => [{'display'=>g1.display_name, 'value'=>g1.id.to_s}, {'display'=>g3.display_name, 'value'=>g3.id.to_s}],
              'meta'        => {'location'=>"https://test.com/mock_users/#{uuid}", 'resourceType'=>'User'},
              'schemas'     => [
                'urn:ietf:params:scim:schemas:core:2.0:User',
                'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User',
                'urn:ietf:params:scim:schemas:extension:manager:1.0:User',
              ],
              'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User' => {
                'organization' => 'SOMEORG',
                'primaryEmail' => instance.work_email_address,
              },
              'urn:ietf:params:scim:schemas:extension:manager:1.0:User' => {}
            })
          end
        end # "context 'and when configured to omit "nil" values in the response'" do"
      end # "context 'with a UUID, renamed primary key column' do"

      context 'with an integer, conventionally named primary key column' do
        it 'compiles instance attribute values into a SCIM representation' do
          instance              = MockGroup.new
          instance.id           = 42
          instance.scim_uid     = 'GG02984'
          instance.display_name = 'Some group'

          scim = instance.to_scim(location: 'https://test.com/mock_groups/42')
          json = scim.to_json()
          hash = JSON.parse(json)

          expect(hash).to eql({
            'displayName' => 'Some group',
            'id'          => '42', # Note, String
            'externalId'  => 'GG02984',
            'members'     => [],
            'meta'        => {'location'=>'https://test.com/mock_groups/42', 'resourceType'=>'Group'},
            'schemas'     => ['urn:ietf:params:scim:schemas:core:2.0:Group']
          })
        end
      end # "context 'with an integer, conventionally named primary key column' do"

      context 'with optional timestamps' do
        context 'creation only' do
          class CreationOnlyTest < MockUser
            attr_accessor :created_at

            def self.scim_timestamps_map
              { created: :created_at }
            end
          end

          it 'renders the creation date/time' do
            instance            = CreationOnlyTest.new
            instance.created_at = Time.now

            scim = instance.to_scim(location: 'https://test.com/mock_users/42')
            json = scim.to_json()
            hash = JSON.parse(json)

            expect(hash['meta']).to eql({
              'created'      => instance.created_at.iso8601(0),
              'location'     => 'https://test.com/mock_users/42',
              'resourceType' => 'User'
            })
          end
        end # "context 'creation only' do"

        context 'update only' do
          class UpdateOnlyTest < MockUser
            attr_accessor :updated_at

            def self.scim_timestamps_map
              { lastModified: :updated_at }
            end
          end

          it 'renders the modification date/time' do
            instance            = UpdateOnlyTest.new
            instance.updated_at = Time.now

            scim = instance.to_scim(location: 'https://test.com/mock_users/42')
            json = scim.to_json()
            hash = JSON.parse(json)

            expect(hash['meta']).to eql({
              'lastModified' => instance.updated_at.iso8601(0),
              'location'     => 'https://test.com/mock_users/42',
              'resourceType' => 'User'
            })
          end
        end # "context 'update only' do"

        context 'create and update' do
          class CreateAndUpdateTest < MockUser
            attr_accessor :created_at, :updated_at

            def self.scim_timestamps_map
              {
                created:      :created_at,
                lastModified: :updated_at
              }
            end
          end

          it 'renders the creation and modification date/times' do
            instance            = CreateAndUpdateTest.new
            instance.created_at = Time.now - 1.month
            instance.updated_at = Time.now

            scim = instance.to_scim(location: 'https://test.com/mock_users/42')
            json = scim.to_json()
            hash = JSON.parse(json)

            expect(hash['meta']).to eql({
              'created'      => instance.created_at.iso8601(0),
              'lastModified' => instance.updated_at.iso8601(0),
              'location'     => 'https://test.com/mock_users/42',
              'resourceType' => 'User'
            })
          end
        end # "context 'create and update' do"
      end # "context 'with optional timestamps' do"

      context 'with arrays' do
        context 'using static mappings' do
          it 'converts to a SCIM representation' do
            instance = StaticMapTest.new(work_email_address: 'work@test.com', home_email_address: 'home@test.com')
            scim     = instance.to_scim(location: 'https://test.com/static_map_test')
            json     = scim.to_json()
            hash     = JSON.parse(json)

            expect(hash).to eql({
              'emails' => [
                {'type'=>'work', 'primary'=>false, 'value'=>'work@test.com'},
                {'type'=>'home',                   'value'=>'home@test.com'},
              ],

              'meta'    => {'location'=>'https://test.com/static_map_test', 'resourceType'=>'User'},
              'schemas' => [
                'urn:ietf:params:scim:schemas:core:2.0:User',
                'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User',
                'urn:ietf:params:scim:schemas:extension:manager:1.0:User',
              ],
              'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User' => {},
              'urn:ietf:params:scim:schemas:extension:manager:1.0:User' => {},
            })
          end
        end # "context 'using static mappings' do"

        context 'using dynamic lists' do
          it 'converts to a SCIM representation' do
            group  = Struct.new(:id, :full_name, keyword_init: true)
            groups = [
              group.new(id: 1, full_name: 'Group 1'),
              group.new(id: 2, full_name: 'Group 2'),
              group.new(id: 3, full_name: 'Group 3'),
            ]

            instance = DynamicMapTest.new(groups: groups)
            scim     = instance.to_scim(location: 'https://test.com/dynamic_map_test')
            json     = scim.to_json()
            hash     = JSON.parse(json)

            expect(hash).to eql({
              'groups' => [
                {'display'=>'Group 1', 'value'=>'1'},
                {'display'=>'Group 2', 'value'=>'2'},
                {'display'=>'Group 3', 'value'=>'3'},
              ],

              'meta'    => {'location'=>'https://test.com/dynamic_map_test', 'resourceType'=>'User'},
              'schemas' => [
                'urn:ietf:params:scim:schemas:core:2.0:User',
                'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User',
                'urn:ietf:params:scim:schemas:extension:manager:1.0:User',
              ],
              'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User' => {},
              'urn:ietf:params:scim:schemas:extension:manager:1.0:User' => {},
            })
          end
        end # "context 'using dynamic lists' do"
      end # "context 'with arrays' do"

      context 'with "returned: \'never\' fields' do
        it 'hides appropriate top-level and nested attributes' do
          instance = NestedReturnedNeverTest.new(
            given_name:          'One',
            last_name:           'Two',
            private_given_name:  'Three',
            private_last_name:   'Four',
            simple_name:         'Five'
          )

          scim = instance.to_scim(location: 'https://test.com/never_retutrned_test')
          json = scim.to_json()
          hash = JSON.parse(json)

          expect(hash).to eql({
            'name'       => { 'givenName' => 'One' },
            'simpleName' => 'Five',

            'meta'    => {'location'=>'https://test.com/never_retutrned_test', 'resourceType'=>'NestedReturnedNeverTestResourse'},
            'schemas' => ['nested-returned-never-id']
          })
        end
      end # "context 'with "returned: \'never\' fields' do"

      context 'with bad definitions' do
        it 'complains about non-Hash entries in mapping Arrays' do
          expect(StaticMapTest).to receive(:scim_attributes_map).and_return({
            emails: [
              'this is not Hash'
            ]
          })

          instance = StaticMapTest.new(work_email_address: 'work@test.com', home_email_address: 'home@test.com')

          expect do
            scim = instance.to_scim(location: 'https://test.com/static_map_test')
          end.to raise_error(RuntimeError) { |e| expect(e.message).to include('Array contains something other than mapping Hash(es)') }
        end

        it 'complains about bad Hash entries in mapping Arrays' do
          expect(StaticMapTest).to receive(:scim_attributes_map).and_return({
            emails: [
              {
                this_is_not: :a_valid_entry
              }
            ]
          })

          instance = StaticMapTest.new(work_email_address: 'work@test.com', home_email_address: 'home@test.com')

          expect do
            scim = instance.to_scim(location: 'https://test.com/static_map_test')
          end.to raise_error(RuntimeError) { |e| expect(e.message).to include('Mapping Hash inside Array does not contain supported data') }
        end
      end # "context 'with bad definitions' do"
    end # "context '#to_scim' do"

    # =========================================================================
    # #from_scim!
    # =========================================================================

    context '#from_scim!' do
      shared_examples 'a creator' do | force_upper_case: |
        context 'which writes instance attribute values from a SCIM representation while' do
          it 'ignoring read-only lists' do
            hash = {
              'userName'     => 'foo',
              'password'     => 'staplebatteryhorsecorrect',
              'name'         => {'givenName' => 'Foo', 'familyName' => 'Bar'},
              'active'       => true,
              'emails'       => [{'type' => 'work',  'primary' => true,  'value' => 'foo.bar@test.com'}],
              'phoneNumbers' => [{'type' => 'work',  'primary' => false, 'value' => '+642201234567'   }],
              'groups'       => [{'type' => 'Group', 'value' => '1'}, {'type' => 'Group', 'value' => '2'}],
              'id'           => '42', # Note, String
              'externalId'   => 'AA02984',
              'meta'         => {'location' => 'https://test.com/mock_users/42', 'resourceType' => 'User'},
              'schemas'      => ['urn:ietf:params:scim:schemas:core:2.0:User', 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User'],

              'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User' => {
                'organization' => 'SOMEORG',
                'DEPARTMENT'   => 'SOMEDPT'
              }
            }

            hash = spec_helper_hupcase(hash) if force_upper_case

            instance = MockUser.new
            instance.home_email_address = 'home@test.com' # Should be cleared as no home e-mail specified in SCIM hash above
            instance.from_scim!(scim_hash: hash)

            expect(instance.scim_uid          ).to eql('AA02984')
            expect(instance.username          ).to eql('foo')
            expect(instance.password          ).to eql('staplebatteryhorsecorrect')
            expect(instance.first_name        ).to eql('Foo')
            expect(instance.last_name         ).to eql('Bar')
            expect(instance.work_email_address).to eql('foo.bar@test.com')
            expect(instance.home_email_address).to be_nil
            expect(instance.work_phone_number ).to eql('+642201234567')
            expect(instance.organization      ).to eql('SOMEORG')
            expect(instance.department        ).to eql('SOMEDPT')
          end

          it 'honouring read-write lists' do
            g1 = MockGroup.create!(display_name: 'Nested group')

            u1 = MockUser.create!(username: '1', first_name: 'Member 1')
            u2 = MockUser.create!(username: '2', first_name: 'Member 2')
            u3 = MockUser.create!(username: '3', first_name: 'Member 3')

            hash = {
              'displayName' => 'Foo Group',
              'members'     => [
                {'type' => 'Group', 'value' => g1.id.to_s},
                {'type' => 'User',  'value' => u1.primary_key.to_s},
                {'type' => 'User',  'value' => u3.primary_key.to_s}
              ],
              'externalId'  => 'GG01536',
              'meta'        => {'location'=>'https://test.com/mock_groups/1', 'resourceType'=>'Group'},
              'schemas'     => ['urn:ietf:params:scim:schemas:core:2.0:Group']
            }

            hash = spec_helper_hupcase(hash) if force_upper_case

            instance = MockGroup.new
            instance.from_scim!(scim_hash: hash)

            expect(instance.scim_uid         ).to eql('GG01536')
            expect(instance.display_name     ).to eql('Foo Group')
            expect(instance.mock_users       ).to match_array([u1, u3])
            expect(instance.child_mock_groups).to match_array([g1])

            instance.save!
            expect(g1.reload.parent_id).to eql(instance.id)
          end

          it 'handling missing inbound lists' do
            hash = {
              'displayName' => 'Foo Group'
            }

            hash = spec_helper_hupcase(hash) if force_upper_case

            instance = MockGroup.new
            instance.from_scim!(scim_hash: hash)

            expect(instance.display_name     ).to eql('Foo Group')
            expect(instance.mock_users       ).to be_empty
            expect(instance.child_mock_groups).to be_empty
          end
        end # "context 'which writes instance attribute values from a SCIM representation while' do"
      end # "shared_examples 'a creator' do | force_upper_case: |"

      context 'using schema-matched case' do
        it_behaves_like 'a creator', force_upper_case: false
      end # "context 'using schema-matched case' do"

      context 'using upper case' do
        it_behaves_like 'a creator', force_upper_case: true
      end # "context 'using upper case' do"

      it 'clears things not present in input' do
        uuid                        = SecureRandom.uuid

        instance                    = MockUser.new
        instance.primary_key        = uuid
        instance.scim_uid           = 'AA02984'
        instance.username           = 'foo'
        instance.first_name         = 'Foo'
        instance.last_name          = 'Bar'
        instance.work_email_address = 'work@test.com'
        instance.home_email_address = 'home@test.com'
        instance.work_phone_number  = '+642201234567'

        instance.from_scim!(scim_hash: {})

        expect(instance.primary_key       ).to eql(uuid)
        expect(instance.scim_uid          ).to be_nil
        expect(instance.username          ).to be_nil
        expect(instance.first_name        ).to be_nil
        expect(instance.last_name         ).to be_nil
        expect(instance.work_email_address).to be_nil
        expect(instance.home_email_address).to be_nil
        expect(instance.work_phone_number ).to be_nil
      end
    end # "context '#from_scim!' do"

    # =========================================================================
    # #from_scim_patch!
    # =========================================================================

    context '#from_scim_patch!' do
      before :each do
        @instance = MockUser.new
      end

      # -------------------------------------------------------------------
      # Internal
      # -------------------------------------------------------------------
      #
      # PATCH is so enormously complex that we do lots of unit tests on private
      # methods before even bothering with the higher level "unit" (more like
      # integration!) tests on #from_scim_patch! itself.
      #
      # These were used during development to debug the implementation.
      #
      context 'internal unit tests' do

        # ---------------------------------------------------------------------
        # Internal: #extract_filter_from
        # ---------------------------------------------------------------------
        #
        context '#extract_filter_from' do
          it 'handles normal path components' do
            path_component, filter = @instance.send(:extract_filter_from, path_component: 'emails')

            expect(path_component).to eql('emails')
            expect(filter        ).to be_nil
          end

          it 'handles path components with filter strings' do
            path_component, filter = @instance.send(:extract_filter_from, path_component: 'addresses[type eq "work"]')

            expect(path_component).to eql('addresses')
            expect(filter        ).to eql('type eq "work"')
          end
        end # "context '#extract_filter_from' do"

        # ---------------------------------------------------------------------
        # Internal: #all_matching_filter
        # ---------------------------------------------------------------------
        #
        context '#all_matching_filter' do
          it 'complains about unsupported operators' do
            expect do
              @instance.send(:all_matching_filter, filter: 'type ne "work"', within_array: []) do
                fail # Block should never be called!
              end
            end.to raise_error(RuntimeError)
          end

          it 'complaints about unsupported multiple operators' do
            expect do
              @instance.send(:all_matching_filter, filter: 'type eq "work" and primary eq true', within_array: []) do
                fail # Block should never be called!
              end
            end.to raise_error(RuntimeError)
          end

          it 'complaints about unsupported multiple operators, handling value spaces' do
            expect do
              @instance.send(:all_matching_filter, filter: 'type eq "work with spaces" and primary pr', within_array: []) do
                fail # Block should never be called!
              end
            end.to raise_error(RuntimeError)
          end

          it 'complaints about unquoted values with spaces' do
            expect do
              @instance.send(:all_matching_filter, filter: 'type eq work with spaces', within_array: []) do
                fail # Block should never be called!
              end
            end.to raise_error(RuntimeError)
          end

          it 'calls block with matches' do
            array = [
              {
                'type'  => 'work',
                'value' => 'work_1@test.com'
              },
              {
                'type'  => 'home',
                'value' => 'home@test.com'
              },
              {
                'type'  => 'work',
                'value' => 'work_2@test.com'
              }
            ]

            unhandled = ['work_1@test.com', 'work_2@test.com']

            @instance.send(:all_matching_filter, filter: 'type eq "work"', within_array: array) do |matched_hash, index|
              expect(array[index]).to eql(matched_hash)

              expect(matched_hash['type']).to eql('work')
              expect(matched_hash).to have_key('value')

              unhandled.delete(matched_hash['value'])
            end

            expect(unhandled).to be_empty
          end

          it 'handles edge cases' do
            array = [
              {
                'type'  => '"work',
                'value' => 'work_leading_dquote@test.com'
              },
              {
                'type'  => true,
                'value' => 'boolean@test.com'
              },
              {
                'type'  => 'work"',
                'value' => 'work_trailing_dquote@test.com'
              },
              {
                'type'  => 'spaced',
                'value' => 'value with spaces'
              }
            ]

            call_count = 0

            @instance.send(:all_matching_filter, filter: 'type eq "work', within_array: array) do |matched_hash, index|
              call_count += 1
              expect(matched_hash['value']).to eql('work_leading_dquote@test.com')
            end

            @instance.send(:all_matching_filter, filter: 'type eq work"', within_array: array) do |matched_hash, index|
              call_count += 1
              expect(matched_hash['value']).to eql('work_trailing_dquote@test.com')
            end

            @instance.send(:all_matching_filter, filter: 'type eq true', within_array: array) do |matched_hash, index|
              call_count += 1
              expect(matched_hash['value']).to eql('boolean@test.com')
            end

            @instance.send(:all_matching_filter, filter: 'value eq "value with spaces"', within_array: array) do |matched_hash, index|
              call_count += 1
              expect(matched_hash['type']).to eql('spaced')
            end

            expect(call_count).to eql(4)
          end
        end # "context '#all_matching_filter' do"

        # ---------------------------------------------------------------------
        # Internal: #from_patch_backend
        # ---------------------------------------------------------------------
        #
        context '#from_patch_backend!' do

          # -------------------------------------------------------------------
          # Internal: #from_patch_backend - add
          # -------------------------------------------------------------------
          #
          # Except for filter and array behaviour at the leaf of the path,
          # "add" and "replace" are pretty much identical.
          #
          context 'add' do
            context 'when prior value already exists' do
              it 'simple value: overwrites' do
                path      = [ 'userName' ]
                scim_hash = { 'userName' => 'bar' }.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'add',
                  path:          path,
                  value:         'foo',
                  altering_hash: scim_hash,
                  with_attr_map: { userName: :user_name }
                )

                expect(scim_hash['userName']).to eql('foo')
              end

              it 'nested simple value: overwrites' do
                path      = [ 'name', 'givenName' ]
                scim_hash = { 'name' => { 'givenName' => 'Foo', 'familyName' => 'Bar' } }.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'add',
                  path:          path,
                  value:         'Baz',
                  altering_hash: scim_hash,
                  with_attr_map: { name: { givenName: :first_name, familyName: :last_name } }
                )

                expect(scim_hash['name']['givenName' ]).to eql('Baz')
                expect(scim_hash['name']['familyName']).to eql('Bar')
              end

              it 'with schema extensions: overwrites' do
                path      = [ 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User', 'organization' ]
                scim_hash = { 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User' => { 'organization' => 'SOMEORG' } }.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'add',
                  path:          path,
                  value:         'OTHERORG',
                  altering_hash: scim_hash,
                  with_attr_map: { organization: :org_name }
                )

                expect(scim_hash['urn:ietf:params:scim:schemas:extension:enterprise:2.0:User']['organization' ]).to eql('OTHERORG')
              end

              # For 'add', filter at end-of-path is nonsensical and not
              # supported by spec or Scimitar; we only test mid-path filters.
              #
              context 'with filter mid-path' do
                it 'by string match: overwrites' do
                  path      = [ 'emails[type eq "work"]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'home',
                        'value' => 'home@test.com'
                      },
                      {
                        'type' => 'work',
                        'value' => 'work@test.com'
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'add',
                    path:          path,
                    value:         'added_over_original@test.com',
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'][0]['value']).to eql('home@test.com')
                  expect(scim_hash['emails'][1]['value']).to eql('added_over_original@test.com')
                end

                it 'by boolean match: overwrites' do
                  path      = [ 'emails[primary eq true]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'value' => 'home@test.com'
                      },
                      {
                        'value' => 'work@test.com',
                        'primary' => true
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'add',
                    path:          path,
                    value:         'added_over_original@test.com',
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'][0]['value']).to eql('home@test.com')
                  expect(scim_hash['emails'][1]['value']).to eql('added_over_original@test.com')
                end

                it 'multiple matches: overwrites all' do
                  path      = [ 'emails[type eq "work"]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'work',
                        'value' => 'work_1@test.com'
                      },
                      {
                        'type' => 'work',
                        'value' => 'work_2@test.com'
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'add',
                    path:          path,
                    value:         'added_over_original@test.com',
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'][0]['value']).to eql('added_over_original@test.com')
                  expect(scim_hash['emails'][1]['value']).to eql('added_over_original@test.com')
                end
              end # "context 'with filter mid-path' do"

              it 'with arrays: appends' do
                path      = [ 'emails' ]
                scim_hash = {
                  'emails' => [
                    {
                      'type' => 'home',
                      'value' => 'home@test.com'
                    }
                  ]
                }.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'add',
                  path:          path,
                  value:         [ { 'type' => 'work', 'value' => 'work@test.com' } ], # NOTE - to-add value is an Array (and must be)
                  altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                )

                expect(scim_hash['emails'].size).to eql(2)
                expect(scim_hash['emails'][1]['type' ]).to eql('work')
                expect(scim_hash['emails'][1]['value']).to eql('work@test.com')
              end

              context 'with complex value addition' do
                it 'adds to arrays' do
                  scim_hash = {
                    'root' => {
                      'members' => [
                        {'value' => '1'},
                        {'value' => '2'}
                      ]
                    }
                  }.with_indifferent_case_insensitive_access()

                  # Example seen at:
                  #
                  #   https://docs.databricks.com/dev-tools/api/latest/scim/scim-groups.html
                  #
                  # The core of it is:
                  #
                  #     "Operations":[
                  #       {
                  #       "op":"add",
                  #       "value":{
                  #           "members":[
                  #              {
                  #                 "value":"<user-id>"
                  #              }
                  #           ]
                  #         }
                  #       }
                  #     ]
                  #
                  # ...so the path is missing ("root"), but the value is
                  # complex and includes implied paths within. We expect to
                  # have the given value Hash added to the members Array,
                  # rather than having e.g. members replaced by this.
                  #
                  @instance.send(
                    :from_patch_backend!,
                    nature:        'add',
                    path:          ['root'],
                    value:         {'members' => [{'value' => '3'}]},
                    altering_hash: scim_hash,
                    with_attr_map: {
                      members: [
                        { list: :members, using: { value: :id } }
                      ]
                    }
                  )

                  expect(scim_hash['root']['members']).to match_array([{'value' => '1'}, {'value' => '2'}, {'value' => '3'}])
                end
              end # "context 'with complex value addition' do"
            end # context 'when prior value already exists' do

            context 'when value is not present' do
              it 'simple value: adds' do
                path      = [ 'userName' ]
                scim_hash = {}.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'add',
                  path:          path,
                  value:         'foo',
                  altering_hash: scim_hash,
                  with_attr_map: { userName: :user_name }
                )

                expect(scim_hash['userName']).to eql('foo')
              end

              it 'nested simple value: adds' do
                path      = [ 'name', 'givenName' ]
                scim_hash = {}.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'add',
                  path:          path,
                  value:         'Baz',
                  altering_hash: scim_hash,
                  with_attr_map: { name: { givenName: :first_name, familyName: :last_name } }
                )

                expect(scim_hash['name']['givenName']).to eql('Baz')
              end

              it 'with schema extensions: adds' do
                path      = [ 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User', 'organization' ]
                scim_hash = {}.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'add',
                  path:          path,
                  value:         'SOMEORG',
                  altering_hash: scim_hash,
                  with_attr_map: { organization: :org_name }
                )

                expect(scim_hash['urn:ietf:params:scim:schemas:extension:enterprise:2.0:User']['organization' ]).to eql('SOMEORG')
              end

              context 'with filter mid-path: adds' do
                it 'by string match' do
                  path      = [ 'emails[type eq "work"]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'home',
                        'value' => 'home@test.com'
                      },
                      {
                        'type' => 'work'
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'add',
                    path:          path,
                    value:         'added@test.com',
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'][0]['value']).to eql('home@test.com')
                  expect(scim_hash['emails'][1]['value']).to eql('added@test.com')
                end

                it 'by boolean match: adds' do
                  path      = [ 'emails[primary eq true]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'value' => 'home@test.com'
                      },
                      {
                        'primary' => true
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'add',
                    path:          path,
                    value:         'added@test.com',
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'][0]['value']).to eql('home@test.com')
                  expect(scim_hash['emails'][1]['value']).to eql('added@test.com')
                end

                it 'with no match: still adds' do
                  path      = [ 'emails[type eq "work"]', 'value' ]
                  scim_hash = {}.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'add',
                    path:          path,
                    value:         'added@test.com',
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'][0]['value']).to eql('added@test.com')
                end

                it 'multiple matches: adds to all' do
                  path      = [ 'emails[type eq "work"]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'work'
                      },
                      {
                        'type' => 'work'
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'add',
                    path:          path,
                    value:         'added@test.com',
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'][0]['value']).to eql('added@test.com')
                  expect(scim_hash['emails'][1]['value']).to eql('added@test.com')
                end
              end # "context 'with filter mid-path' do"

              it 'with arrays: appends' do
                path      = [ 'emails' ]
                scim_hash = {}.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'add',
                  path:          path,
                  value:         [ { 'type' => 'work', 'value' => 'work@test.com' } ], # NOTE - to-add value is an Array (and must be)
                  altering_hash: scim_hash,
                  with_attr_map: {
                    emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                      { match: 'type', with: 'work', using: { value: :work_email } },
                    ]
                  }
                )

                expect(scim_hash['emails'].size).to eql(1)
                expect(scim_hash['emails'][0]['type' ]).to eql('work')
                expect(scim_hash['emails'][0]['value']).to eql('work@test.com')
              end
            end # context 'when value is not present' do
          end # "context 'add' do"

          # -------------------------------------------------------------------
          # Internal: #from_patch_backend - remove
          # -------------------------------------------------------------------
          #
          context 'remove' do
            context 'when prior value already exists' do
              it 'simple value: clears to "nil" in order to remove' do
                path      = [ 'userName' ]
                scim_hash = { 'userName' => 'bar' }.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'remove',
                  path:          path,
                  value:         nil,
                  altering_hash: scim_hash,
                  with_attr_map: { userName: :user_name }
                )

                expect(scim_hash).to eql({ 'userName' => nil })
              end

              it 'nested simple value: clears to "nil" in order to remove' do
                path      = [ 'name', 'givenName' ]
                scim_hash = { 'name' => { 'givenName' => 'Foo', 'familyName' => 'Bar' } }.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'remove',
                  path:          path,
                  value:         nil,
                  altering_hash: scim_hash,
                  with_attr_map: { name: { givenName: :first_name, familyName: :last_name } }
                )

                expect(scim_hash).to eql({ 'name' => { 'givenName' => nil, 'familyName' => 'Bar' } })
              end

              context 'with filter mid-path' do
                it 'by string match: clears to "nil" in order to remove' do
                  path      = [ 'emails[type eq "work"]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'home',
                        'value' => 'home@test.com'
                      },
                      {
                        'type' => 'work',
                        'value' => 'work@test.com'
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'remove',
                    path:          path,
                    value:         nil,
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash).to eql({
                    'emails' => [
                      {
                        'type' => 'home',
                        'value' => 'home@test.com'
                      },
                      {
                        'type' => 'work',
                        'value' => nil
                      }
                    ]
                  })
                end

                it 'by boolean match: clears to "nil" in order to remove' do
                  path      = [ 'emails[primary eq true]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'value' => 'home@test.com'
                      },
                      {
                        'value' => 'work@test.com',
                        'primary' => true
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'remove',
                    path:          path,
                    value:         nil,
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash).to eql({
                    'emails' => [
                      {
                        'value' => 'home@test.com'
                      },
                      {
                        'value' => nil,
                        'primary' => true
                      }
                    ]
                  })
                end

                it 'multiple matches: clears all to "nil" in order to remove' do
                  path      = [ 'emails[type eq "work"]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'work',
                        'value' => 'work_1@test.com'
                      },
                      {
                        'type' => 'work',
                        'value' => 'work_2@test.com'
                      },
                      {
                        'type' => 'home',
                        'value' => 'home@test.com'
                      },
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'remove',
                    path:          path,
                    value:         nil,
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash).to eql({
                    'emails' => [
                      {
                        'type' => 'work',
                        'value' => nil
                      },
                      {
                        'type' => 'work',
                        'value' => nil
                      },
                      {
                        'type' => 'home',
                        'value' => 'home@test.com'
                      },
                    ]
                  })
                end
              end # "context 'with filter mid-path' do"

              context 'with filter at end of path' do
                it 'by string match: clears to "nil" in order to remove' do
                  path      = [ 'emails[type eq "work"]' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'home',
                        'value' => 'home@test.com'
                      },
                      {
                        'type' => 'work',
                        'value' => 'work@test.com'
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'remove',
                    path:          path,
                    value:         nil,
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash).to eql({
                    'emails' => [
                      {
                        'type' => 'home',
                        'value' => 'home@test.com'
                      },
                      {
                        'type' => 'work',
                        'value' => nil
                      }
                    ]
                  })
                end

                it 'by boolean match: clears to "nil" in order to remove' do
                  path      = [ 'emails[primary eq true]' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'value' => 'home@test.com',
                        'primary' => true
                      },
                      {
                        'value' => 'work@test.com'
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'remove',
                    path:          path,
                    value:         nil,
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash).to eql({
                    'emails' => [
                      {
                        'value' => nil,
                        'primary' => true
                      },
                      {
                        'value' => 'work@test.com'
                      }
                    ]
                  })
                end

                it 'multiple matches: clears all to "nil" in order to remove' do
                  path      = [ 'emails[type eq "work"]' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'work',
                        'value' => 'work_1@test.com'
                      },
                      {
                        'type' => 'work',
                        'value' => 'work_2@test.com'
                      },
                      {
                        'type' => 'home',
                        'value' => 'home@test.com'
                      },
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'remove',
                    path:          path,
                    value:         nil,
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash).to eql({
                    'emails' => [
                      {
                        'type' => 'work',
                        'value' => nil
                      },
                      {
                        'type' => 'work',
                        'value' => nil
                      },
                      {
                        'type' => 'home',
                        'value' => 'home@test.com'
                      },
                    ]
                  })
                end
              end # "context 'with filter at end of path' do"

              it 'whole array: clears mapped values to "nil" to remove them' do
                path      = [ 'emails' ]
                scim_hash = {
                  'emails' => [
                    {
                      'type' => 'home',
                      'value' => 'home@test.com'
                    },
                    {
                      'type' => 'work',
                      'value' => 'work@test.com'
                    }
                  ]
                }.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'remove',
                  path:          path,
                  value:         nil,
                  altering_hash: scim_hash,
                  with_attr_map: {
                    emails: [
                      { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                      { match: 'type', with: 'work', using: { value: :work_email } },
                    ]
                  }
                )

                expect(scim_hash).to eql({
                  'emails' => [
                    {
                      'type' => 'home',
                      'value' => nil
                    },
                    {
                      'type' => 'work',
                      'value' => nil
                    }
                  ]
                })
              end

              # What we expect:
              #
              # https://tools.ietf.org/html/rfc7644#section-3.5.2.2
              # https://docs.snowflake.com/en/user-guide/scim-intro.html#patch-scim-v2-groups-id
              #
              # ...vs accounting for the unusual payloads we sometimes get,
              # tested here.
              #
              context 'special cases' do

                # https://learn.microsoft.com/en-us/azure/active-directory/app-provisioning/use-scim-to-provision-users-and-groups#update-group-remove-members
                #
                context 'Microsoft-style payload' do
                  context 'removing a user from a group' do
                    it 'removes identified user' do
                      path      = [ 'members' ]
                      value     = [ { '$ref' => nil, 'value' => 'f648f8d5ea4e4cd38e9c' } ]
                      scim_hash = {
                        'displayname' => 'Mock group',
                        'members'     => [
                          {
                            'value'   => '50ca93d04ab0c2de4772',
                            'display' => 'Ingrid Smith',
                            'type'    => 'User'
                          },
                          {
                            'value'   => 'f648f8d5ea4e4cd38e9c',
                            'display' => 'Fred Smith',
                            'type'    => 'User'
                          },
                          {
                            'value'   => 'a774d480e8112101375b',
                            'display' => 'Taylor Smith',
                            'type'    => 'User'
                          }
                        ]
                      }.with_indifferent_case_insensitive_access()

                      @instance.send(
                        :from_patch_backend!,
                        nature:        'remove',
                        path:          path,
                        value:         value,
                        altering_hash: scim_hash,
                        with_attr_map: {
                          members: [
                            { list: :members, using: { value: :id, display: :full_name, type: 'User' } }
                          ]
                        }
                      )

                      expect(scim_hash).to eql({
                        'displayname' => 'Mock group',
                        'members'     => [
                          {
                            'value'   => '50ca93d04ab0c2de4772',
                            'display' => 'Ingrid Smith',
                            'type'    => 'User'
                          },
                          {
                            'value'   => 'a774d480e8112101375b',
                            'display' => 'Taylor Smith',
                            'type'    => 'User'
                          }
                        ]
                      })
                    end

                    it 'removes multiple identified users' do
                      path      = [ 'members' ]
                      value     = [
                        { '$ref' => nil, 'value' => 'f648f8d5ea4e4cd38e9c' },
                        { '$ref' => nil, 'value' => '50ca93d04ab0c2de4772' }
                      ]
                      scim_hash = {
                        'displayname' => 'Mock group',
                        'members'     => [
                          {
                            'value'   => '50ca93d04ab0c2de4772',
                            'display' => 'Ingrid Smith',
                            'type'    => 'User'
                          },
                          {
                            'value'   => 'f648f8d5ea4e4cd38e9c',
                            'display' => 'Fred Smith',
                            'type'    => 'User'
                          },
                          {
                            'value'   => 'a774d480e8112101375b',
                            'display' => 'Taylor Smith',
                            'type'    => 'User'
                          }
                        ]
                      }.with_indifferent_case_insensitive_access()

                      @instance.send(
                        :from_patch_backend!,
                        nature:        'remove',
                        path:          path,
                        value:         value,
                        altering_hash: scim_hash,
                        with_attr_map: {
                          members: [
                            { list: :members, using: { value: :id, display: :full_name, type: 'User' } }
                          ]
                        }
                      )

                      expect(scim_hash).to eql({
                        'displayname' => 'Mock group',
                        'members'     => [
                          {
                            'value'   => 'a774d480e8112101375b',
                            'display' => 'Taylor Smith',
                            'type'    => 'User'
                          }
                        ]
                      })
                    end

                    it 'removes all users individually without error' do
                      path      = [ 'members' ]
                      value     = [ { '$ref' => nil, 'value' => 'f648f8d5ea4e4cd38e9c' } ]
                      scim_hash = {
                        'displayname' => 'Mock group',
                        'members'     => [
                          {
                            'value'   => 'f648f8d5ea4e4cd38e9c',
                            'display' => 'Fred Smith',
                            'type'    => 'User'
                          }
                        ]
                      }.with_indifferent_case_insensitive_access()

                      @instance.send(
                        :from_patch_backend!,
                        nature:        'remove',
                        path:          path,
                        value:         value,
                        altering_hash: scim_hash,
                        with_attr_map: {
                          members: [
                            { list: :members, using: { value: :id, display: :full_name, type: 'User' } }
                          ]
                        }
                      )

                      expect(scim_hash).to eql({
                        'displayname' => 'Mock group',
                        'members'     => []
                      })
                    end

                    it 'can match on multiple attributes' do
                      path      = [ 'members' ]
                      value     = [ { '$ref' => nil, 'value' => 'f648f8d5ea4e4cd38e9c', 'type' => 'User' } ]
                      scim_hash = {
                        'displayname' => 'Mock group',
                        'members'     => [
                          {
                            'value'   => 'f648f8d5ea4e4cd38e9c',
                            'display' => 'Fred Smith',
                            'type'    => 'User'
                          }
                        ]
                      }.with_indifferent_case_insensitive_access()

                      @instance.send(
                        :from_patch_backend!,
                        nature:        'remove',
                        path:          path,
                        value:         value,
                        altering_hash: scim_hash,
                        with_attr_map: {
                          members: [
                            { list: :members, using: { value: :id, display: :full_name, type: 'User' } }
                          ]
                        }
                      )

                      expect(scim_hash).to eql({
                        'displayname' => 'Mock group',
                        'members'     => []
                      })
                    end

                    it 'ignores unrecognised users' do
                      path      = [ 'members' ]
                      value     = [ { '$ref' => nil, 'value' => '11b054a9c85216ed9356' } ]
                      scim_hash = {
                        'displayname' => 'Mock group',
                        'members'     => [
                          {
                            'value'   => 'f648f8d5ea4e4cd38e9c',
                            'display' => 'Fred Smith',
                            'type'    => 'User'
                          }
                        ]
                      }.with_indifferent_case_insensitive_access()

                      @instance.send(
                        :from_patch_backend!,
                        nature:        'remove',
                        path:          path,
                        value:         value,
                        altering_hash: scim_hash,
                        with_attr_map: {
                          members: [
                            { list: :members, using: { value: :id, display: :full_name, type: 'User' } }
                          ]
                        }
                      )

                      # The 'value' mismatched, so the user was not removed.
                      #
                      expect(scim_hash).to eql({
                        'displayname' => 'Mock group',
                        'members'     => [
                          {
                            'value'   => 'f648f8d5ea4e4cd38e9c',
                            'display' => 'Fred Smith',
                            'type'    => 'User'
                          }
                        ]
                      })
                    end

                    it 'ignores a mismatch on (for example) "type"' do
                      path      = [ 'members' ]
                      value     = [ { '$ref' => nil, 'value' => 'f648f8d5ea4e4cd38e9c', 'type' => 'Group' } ]
                      scim_hash = {
                        'displayname' => 'Mock group',
                        'members'     => [
                          {
                            'value'   => 'f648f8d5ea4e4cd38e9c',
                            'display' => 'Fred Smith',
                            'type'    => 'User'
                          }
                        ]
                      }.with_indifferent_case_insensitive_access()

                      @instance.send(
                        :from_patch_backend!,
                        nature:        'remove',
                        path:          path,
                        value:         value,
                        altering_hash: scim_hash,
                        with_attr_map: {
                          members: [
                            { list: :members, using: { value: :id, display: :full_name, type: 'User' } }
                          ]
                        }
                      )

                      # Type 'Group' mismatches 'User', so the user was not
                      # removed.
                      #
                      expect(scim_hash).to eql({
                        'displayname' => 'Mock group',
                        'members'     => [
                          {
                            'value'   => 'f648f8d5ea4e4cd38e9c',
                            'display' => 'Fred Smith',
                            'type'    => 'User'
                          }
                        ]
                      })
                    end

                    it 'matches keys case-insensitive (but preserves case in response)' do
                      path      = [ 'members' ]
                      value     = [ { '$ref' => nil, 'VALUe' => 'f648f8d5ea4e4cd38e9c' } ]
                      scim_hash = {
                        'displayname' => 'Mock group',
                        'memBERS'     => [
                          {
                            'vaLUe'   => 'f648f8d5ea4e4cd38e9c',
                            'display' => 'Fred Smith',
                            'type'    => 'User'
                          }
                        ]
                      }.with_indifferent_case_insensitive_access()

                      @instance.send(
                        :from_patch_backend!,
                        nature:        'remove',
                        path:          path,
                        value:         value,
                        altering_hash: scim_hash,
                        with_attr_map: {
                          members: [
                            { list: :members, using: { value: :id, display: :full_name, type: 'User' } }
                          ]
                        }
                      )

                      expect(scim_hash).to eql({
                        'displayname' => 'Mock group',
                        'memBERS'     => []
                      })
                    end

                    it 'matches values case-sensitive' do
                      path      = [ 'members' ]
                      value     = [ { '$ref' => nil, 'value' => 'f648f8d5ea4e4cd38e9c', 'type' => 'USER' } ]
                      scim_hash = {
                        'displayName' => 'Mock group',
                        'members'     => [
                          {
                            'value'   => 'f648f8d5ea4e4cd38e9c',
                            'display' => 'Fred Smith',
                            'type'    => 'User'
                          }
                        ]
                      }.with_indifferent_case_insensitive_access()

                      @instance.send(
                        :from_patch_backend!,
                        nature:        'remove',
                        path:          path,
                        value:         value,
                        altering_hash: scim_hash,
                        with_attr_map: {
                          members: [
                            { list: :members, using: { value: :id, display: :full_name, type: 'User' } }
                          ]
                        }
                      )

                      # USER mismatches User, so the user was not removed.
                      #
                      expect(scim_hash).to eql({
                        'displayName' => 'Mock group',
                        'members'     => [
                          {
                            'value'   => 'f648f8d5ea4e4cd38e9c',
                            'display' => 'Fred Smith',
                            'type'    => 'User'
                          }
                        ]
                      })
                    end
                  end # "context 'removing a user from a group' do"

                  context 'generic use' do
                    it 'clears static map matched items to "nil" in order to remove' do
                      path      = [ 'emails' ]
                      value     = [ { 'type' => 'work' } ]
                      scim_hash = {
                        'emails' => [
                          {
                            'type' => 'home',
                            'value' => 'home@test.com'
                          },
                          {
                            'type' => 'work',
                            'value' => 'work@test.com'
                          }
                        ]
                      }.with_indifferent_case_insensitive_access()

                      @instance.send(
                        :from_patch_backend!,
                        nature:        'remove',
                        path:          path,
                        value:         value,
                        altering_hash: scim_hash,
                        with_attr_map: {
                          emails: [
                            { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                            { match: 'type', with: 'work', using: { value: :work_email } },
                          ]
                        }
                      )

                      expect(scim_hash).to eql({
                        'emails' => [
                          {
                            'type' => 'home',
                            'value' => 'home@test.com'
                          },
                          {
                            'type' => 'work',
                            'value' => nil
                          }
                        ]
                      })
                    end

                    it 'ignores unmatched items' do
                      path      = [ 'emails' ]
                      value     = [ { 'type' => 'missing' } ]
                      scim_hash = {
                        'emails' => [
                          {
                            'type' => 'home',
                            'value' => 'home@test.com'
                          },
                          {
                            'type' => 'work',
                            'value' => 'work@test.com'
                          }
                        ]
                      }.with_indifferent_case_insensitive_access()

                      @instance.send(
                        :from_patch_backend!,
                        nature:        'remove',
                        path:          path,
                        value:         value,
                        altering_hash: scim_hash,
                        with_attr_map: {
                          emails: [
                            { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                            { match: 'type', with: 'work', using: { value: :work_email } },
                          ]
                        }
                      )

                      expect(scim_hash).to eql({
                        'emails' => [
                          {
                            'type' => 'home',
                            'value' => 'home@test.com'
                          },
                          {
                            'type' => 'work',
                            'value' => 'work@test.com'
                          }
                        ]
                      })
                    end

                    it 'compares string forms' do
                      path      = [ 'test' ]
                      value     = [
                        { 'active' => true,    'value' => '12' },
                        { 'active' => 'false', 'value' => 42   }
                      ]
                      scim_hash = {
                        'test' => [
                          {
                            'active' => 'true',
                            'value' => 12
                          },
                          {
                            'active' => false,
                            'value' => '42'
                          },
                          {
                            'active' => 'hello',
                            'value'  => 'world'
                          }
                        ]
                      }.with_indifferent_case_insensitive_access()

                      @instance.send(
                        :from_patch_backend!,
                        nature:        'remove',
                        path:          path,
                        value:         value,
                        altering_hash: scim_hash,
                        with_attr_map: {
                          test: [
                            {
                              list: :test,
                              using: {
                                active: :active,
                                value:  :value
                              }
                            }
                          ]
                        }
                      )

                      expect(scim_hash).to eql({
                        'test' => [
                          {
                            'active' => 'hello',
                            'value'  => 'world'
                          }
                        ]
                      })
                    end

                    it 'handles a singular to-remove value rather than an array' do
                      path      = [ 'emails' ]
                      value     = { 'type' => 'work' }
                      scim_hash = {
                        'emails' => [
                          {
                            'type' => 'home',
                            'value' => 'home@test.com'
                          },
                          {
                            'type' => 'work',
                            'value' => 'work@test.com'
                          }
                        ]
                      }.with_indifferent_case_insensitive_access()

                      @instance.send(
                        :from_patch_backend!,
                        nature:        'remove',
                        path:          path,
                        value:         value,
                        altering_hash: scim_hash,
                        with_attr_map: {
                          emails: [
                            { match: 'type', with: 'home', using: { value: :home_email } },
                            { match: 'type', with: 'work', using: { value: :work_email } },
                          ]
                        }
                      )

                      expect(scim_hash).to eql({
                        'emails' => [
                          {
                            'type' => 'home',
                            'value' => 'home@test.com'
                          },
                          {
                            'type' => 'work',
                            'value' => nil
                          }
                        ]
                      })
                    end

                    it 'handles simple values rather than object (Hash) values' do
                      path      = [ 'test' ]
                      value     = 42
                      scim_hash = {
                        'test' => [
                          '21',
                          '42',
                          '15'
                        ]
                      }.with_indifferent_case_insensitive_access()

                      @instance.send(
                        :from_patch_backend!,
                        nature:        'remove',
                        path:          path,
                        value:         value,
                        altering_hash: scim_hash,
                        with_attr_map: {
                          test: []
                        }
                      )

                      expect(scim_hash).to eql({
                        'test' => [
                          '21',
                          '15'
                        ]
                      })
                    end
                  end
                end # "context 'Microsoft-style payload' do"

                # https://help.salesforce.com/s/articleView?id=sf.identity_scim_manage_groups.htm&type=5
                #
                context 'Salesforce-style payload' do
                  it 'removes identified user' do
                    path      = [ 'members' ]
                    value     = { 'members' => [ { '$ref' => nil, 'value' => 'f648f8d5ea4e4cd38e9c' } ] }
                    scim_hash = {
                      'displayname' => 'Mock group',
                      'members'     => [
                        {
                          'value'   => '50ca93d04ab0c2de4772',
                          'display' => 'Ingrid Smith',
                          'type'    => 'User'
                        },
                        {
                          'value'   => 'f648f8d5ea4e4cd38e9c',
                          'display' => 'Fred Smith',
                          'type'    => 'User'
                        }
                      ]
                    }.with_indifferent_case_insensitive_access()

                    @instance.send(
                      :from_patch_backend!,
                      nature:        'remove',
                      path:          path,
                      value:         value,
                      altering_hash: scim_hash,
                      with_attr_map: {
                        displayName: :name,
                        members:     [
                          list:  :members,
                          using: {
                            value:   :id,
                            display: :full_name,
                            type:    'User'
                          }
                        ]
                      }
                    )

                    expect(scim_hash).to eql({
                      'displayname' => 'Mock group',
                      'members'     => [
                        {
                          'value'   => '50ca93d04ab0c2de4772',
                          'display' => 'Ingrid Smith',
                          'type'    => 'User'
                        }
                      ]
                    })
                  end

                  it 'matches the "members" key case-insensitive' do
                    path      = [ 'members' ]
                    value     = { 'MEMBERS' => [ { '$ref' => nil, 'value' => 'f648f8d5ea4e4cd38e9c' } ] }
                    scim_hash = {
                      'displayname' => 'Mock group',
                      'members'     => [
                        {
                          'value'   => 'f648f8d5ea4e4cd38e9c',
                          'display' => 'Fred Smith',
                          'type'    => 'User'
                        },
                        {
                          'value'   => 'a774d480e8112101375b',
                          'display' => 'Taylor Smith',
                          'type'    => 'User'
                        }
                      ]
                    }.with_indifferent_case_insensitive_access()

                    @instance.send(
                      :from_patch_backend!,
                      nature:        'remove',
                      path:          path,
                      value:         value,
                      altering_hash: scim_hash,
                      with_attr_map: {
                        displayName: :name,
                        members:     [
                          list:  :members,
                          using: {
                            value:   :id,
                            display: :full_name,
                            type:    'User'
                          }
                        ]
                      }
                    )

                    expect(scim_hash).to eql({
                      'displayname' => 'Mock group',
                      'members'     => [
                        {
                          'value'   => 'a774d480e8112101375b',
                          'display' => 'Taylor Smith',
                          'type'    => 'User'
                        }
                      ]
                    })
                  end

                  it 'ignores unrecognised users' do
                    path      = [ 'members' ]
                    value     = { 'members' => [ { '$ref' => nil, 'value' => '11b054a9c85216ed9356' } ] }
                    scim_hash = {
                      'displayname' => 'Mock group',
                      'members'     => [
                        {
                          'value'   => 'f648f8d5ea4e4cd38e9c',
                          'display' => 'Fred Smith',
                          'type'    => 'User'
                        }
                      ]
                    }.with_indifferent_case_insensitive_access()

                    @instance.send(
                      :from_patch_backend!,
                      nature:        'remove',
                      path:          path,
                      value:         value,
                      altering_hash: scim_hash,
                      with_attr_map: {
                        displayName: :name,
                        members:     [
                          list:  :members,
                          using: {
                            value:   :id,
                            display: :full_name,
                            type:    'User'
                          }
                        ]
                      }
                    )

                    # The 'value' mismatched, so the user was not removed.
                    #
                    expect(scim_hash).to eql({
                      'displayname' => 'Mock group',
                      'members'     => [
                        {
                          'value'   => 'f648f8d5ea4e4cd38e9c',
                          'display' => 'Fred Smith',
                          'type'    => 'User'
                        }
                      ]
                    })
                  end
                end # "context 'Salesforce-style payload' do"
              end # "context 'special cases' do"
            end # context 'when prior value already exists' do

            context 'when value is not present' do
              it 'simple value: does nothing' do
                path      = [ 'userName' ]
                scim_hash = {}.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'remove',
                  path:          path,
                  value:         nil,
                  altering_hash: scim_hash,
                  with_attr_map: { userName: :user_name }
                )

                expect(scim_hash).to be_empty
              end

              it 'nested simple value: does nothing' do
                path      = [ 'name', 'givenName' ]
                scim_hash = { 'name' => {'familyName' => 'Bar' } }.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'remove',
                  path:          path,
                  value:         nil,
                  altering_hash: scim_hash,
                  with_attr_map: { name: { givenName: :first_name, familyName: :last_name } }
                )

                expect(scim_hash['name']).to_not have_key('givenName')
                expect(scim_hash['name']['familyName']).to eql('Bar')
              end

              context 'with filter mid-path' do
                it 'by string match: does nothing' do
                  path      = [ 'emails[type eq "work"]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'home',
                        'value' => 'home@test.com'
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'remove',
                    path:          path,
                    value:         nil,
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'].size).to eql(1)
                  expect(scim_hash['emails'][0]['value']).to eql('home@test.com')
                end

                it 'by boolean match: does nothing' do
                  path      = [ 'emails[primary eq true]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'value' => 'home@test.com'
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'remove',
                    path:          path,
                    value:         nil,
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'].size).to eql(1)
                  expect(scim_hash['emails'][0]['value']).to eql('home@test.com')
                end

                it 'multiple matches: does nothing' do
                  path      = [ 'emails[type eq "work"]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'home',
                        'value' => 'home@test.com'
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'remove',
                    path:          path,
                    value:         nil,
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'].size).to eql(1)
                  expect(scim_hash['emails'][0]['value']).to eql('home@test.com')
                end
              end # "context 'with filter mid-path' do"

              context 'with filter at end of path' do
                it 'by string match: does nothing' do
                  path      = [ 'emails[type eq "work"]' ]
                  scim_hash = {}.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'remove',
                    path:          path,
                    value:         nil,
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash).to be_empty
                end

                it 'by boolean match: does nothing' do
                  path      = [ 'emails[primary eq true]' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'value' => 'home@test.com',
                        'primary' => false
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'remove',
                    path:          path,
                    value:         nil,
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'].size).to eql(1)
                  expect(scim_hash['emails'][0]['value']).to eql('home@test.com')
                end
              end # "context 'with filter at end of path' do"

              it 'remove whole array: does nothing' do
                path      = [ 'emails' ]
                scim_hash = {}.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'remove',
                  path:          path,
                  value:         nil,
                  altering_hash: scim_hash,
                  with_attr_map: {
                    emails: [
                      { match: 'type', with: 'home', using: { value: :home_email } },
                      { match: 'type', with: 'work', using: { value: :work_email } },
                    ]
                  }
                )

                expect(scim_hash).to_not have_key('emails')
              end
            end # context 'when value is not present' do
          end # "context 'remove' do"

          # -------------------------------------------------------------------
          # Internal: #from_patch_backend - replace
          # -------------------------------------------------------------------
          #
          # Except for filter and array behaviour at the leaf of the path,
          # "add" and "replace" are pretty much identical.
          #
          context 'replace' do
            context 'when prior value already exists' do
              it 'simple value: overwrites' do
                path      = [ 'userName' ]
                scim_hash = { 'userName' => 'bar' }.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'replace',
                  path:          path,
                  value:         'foo',
                  altering_hash: scim_hash,
                  with_attr_map: { userName: :user_name }
                )

                expect(scim_hash['userName']).to eql('foo')
              end

              it 'nested simple value: overwrites' do
                path      = [ 'name', 'givenName' ]
                scim_hash = { 'name' => { 'givenName' => 'Foo', 'familyName' => 'Bar' } }.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'replace',
                  path:          path,
                  value:         'Baz',
                  altering_hash: scim_hash,
                  with_attr_map: { name: { givenName: :first_name, familyName: :last_name } }
                )

                expect(scim_hash['name']['givenName' ]).to eql('Baz')
                expect(scim_hash['name']['familyName']).to eql('Bar')
              end

              context 'with filter mid-path' do
                it 'by string match: overwrites' do
                  path      = [ 'emails[type eq "work"]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'home',
                        'value' => 'home@test.com'
                      },
                      {
                        'type' => 'work',
                        'value' => 'work@test.com'
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'replace',
                    path:          path,
                    value:         'added_over_original@test.com',
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'][0]['value']).to eql('home@test.com')
                  expect(scim_hash['emails'][1]['value']).to eql('added_over_original@test.com')
                end

                it 'by boolean match: overwrites' do
                  path      = [ 'emails[primary eq true]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'value' => 'home@test.com'
                      },
                      {
                        'value' => 'work@test.com',
                        'primary' => true
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'replace',
                    path:          path,
                    value:         'added_over_original@test.com',
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'][0]['value']).to eql('home@test.com')
                  expect(scim_hash['emails'][1]['value']).to eql('added_over_original@test.com')
                end

                it 'multiple matches: overwrites all' do
                  path      = [ 'emails[type eq "work"]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'work',
                        'value' => 'work_1@test.com'
                      },
                      {
                        'type' => 'work',
                        'value' => 'work_2@test.com'
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'replace',
                    path:          path,
                    value:         'added_over_original@test.com',
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'][0]['value']).to eql('added_over_original@test.com')
                  expect(scim_hash['emails'][1]['value']).to eql('added_over_original@test.com')
                end
              end # "context 'with filter mid-path' do"

              context 'with filter at end of path' do
                it 'by string match: replaces matching array entry' do
                  path      = [ 'emails[type eq "work"]' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'holiday',
                        'value' => 'holiday@test.com'
                      },
                      {
                        'type' => 'work',
                        'value' => 'work@test.com'
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'replace',
                    path:          path,
                    value:         {'type' => 'home', 'primary' => true, 'value' => 'home@test.com'},
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'].size).to eql(2)
                  expect(scim_hash['emails'][0]['type'   ]).to eql('holiday') # unchanged
                  expect(scim_hash['emails'][1]['type'   ]).to eql('home') # "work" became "home"
                  expect(scim_hash['emails'][1]['primary']).to eql(true)
                  expect(scim_hash['emails'][1]['value'  ]).to eql('home@test.com')
                end

                it 'multiple matches: replaces all matching array entries' do
                  path      = [ 'emails[type eq "work"]' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'work',
                        'value' => 'work_1@test.com'
                      },
                      {
                        'type' => 'work',
                        'value' => 'work_2@test.com'
                      },
                      {
                        'type' => 'home',
                        'value' => 'home@test.com'
                      },
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'replace',
                    path:          path,
                    value:         {'type' => 'workinate', 'value' => 'replaced@test.com'},
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'].size).to eql(3)
                  expect(scim_hash['emails'][0]['type' ]).to eql('workinate')
                  expect(scim_hash['emails'][0]['value']).to eql('replaced@test.com')
                  expect(scim_hash['emails'][1]['type' ]).to eql('workinate')
                  expect(scim_hash['emails'][1]['value']).to eql('replaced@test.com')
                  expect(scim_hash['emails'][2]['type' ]).to eql('home')
                  expect(scim_hash['emails'][2]['value']).to eql('home@test.com')
                end
              end # "context 'with filter at end of path' do"

              it 'with arrays: replaces whole array' do
                path      = [ 'emails' ]
                scim_hash = {
                  'emails' => [
                    {
                      'type' => 'home',
                      'value' => 'home@test.com'
                    }
                  ]
                }.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'replace',
                  path:          path,
                  value:         [ { 'type' => 'work', 'value' => 'work@test.com' } ], # NOTE - to-add value is an Array (and must be)
                  altering_hash: scim_hash,
                  with_attr_map: {
                    emails: [
                      { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                      { match: 'type', with: 'work', using: { value: :work_email } },
                    ]
                  }
                )

                expect(scim_hash['emails'].size).to eql(1)
                expect(scim_hash['emails'][0]['type' ]).to eql('work')
                expect(scim_hash['emails'][0]['value']).to eql('work@test.com')
              end
            end # context 'when prior value already exists' do

            context 'when value is not present' do
              it 'simple value: adds' do
                path      = [ 'userName' ]
                scim_hash = {}.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'replace',
                  path:          path,
                  value:         'foo',
                  altering_hash: scim_hash,
                  with_attr_map: { userName: :user_name }
                )

                expect(scim_hash['userName']).to eql('foo')
              end

              it 'nested simple value: adds' do
                path      = [ 'name', 'givenName' ]
                scim_hash = {}.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'replace',
                  path:          path,
                  value:         'Baz',
                  altering_hash: scim_hash,
                  with_attr_map: { name: { givenName: :first_name, familyName: :last_name } }
                )

                expect(scim_hash['name']['givenName']).to eql('Baz')
              end

              context 'with filter mid-path: adds' do
                it 'by string match' do
                  path      = [ 'emails[type eq "work"]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'home',
                        'value' => 'home@test.com'
                      },
                      {
                        'type' => 'work'
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'replace',
                    path:          path,
                    value:         'added@test.com',
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'][0]['value']).to eql('home@test.com')
                  expect(scim_hash['emails'][1]['value']).to eql('added@test.com')
                end

                it 'by boolean match: adds' do
                  path      = [ 'emails[primary eq true]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'value' => 'home@test.com'
                      },
                      {
                        'primary' => true
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'replace',
                    path:          path,
                    value:         'added@test.com',
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'][0]['value']).to eql('home@test.com')
                  expect(scim_hash['emails'][1]['value']).to eql('added@test.com')
                end

                it 'multiple matches: adds to all' do
                  path      = [ 'emails[type eq "work"]', 'value' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'type' => 'work'
                      },
                      {
                        'type' => 'work'
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'replace',
                    path:          path,
                    value:         'added@test.com',
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'][0]['value']).to eql('added@test.com')
                  expect(scim_hash['emails'][1]['value']).to eql('added@test.com')
                end
              end # "context 'with filter mid-path' do"

              context 'with filter at end of path' do
                it 'by string match: adds item' do
                  path      = [ 'emails[type eq "work"]' ]
                  scim_hash = {}.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'replace',
                    path:          path,
                    value:         {'type' => 'work', 'value' => 'work@test.com'},
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'].size).to eql(1)
                  expect(scim_hash['emails'][0]['type' ]).to eql('work')
                  expect(scim_hash['emails'][0]['value']).to eql('work@test.com')
                end

                it 'by boolean match: adds item' do
                  path      = [ 'emails[primary eq true]' ]
                  scim_hash = {
                    'emails' => [
                      {
                        'value' => 'home@test.com',
                        'primary' => false
                      }
                    ]
                  }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'replace',
                    path:          path,
                    value:         {'type' => 'work', 'value' => 'work@test.com'},
                    altering_hash: scim_hash,
                    with_attr_map: {
                      emails: [
                        { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                        { match: 'type', with: 'work', using: { value: :work_email } },
                      ]
                    }
                  )

                  expect(scim_hash['emails'].size).to eql(2)
                  expect(scim_hash['emails'][0]['value']).to eql('home@test.com')
                  expect(scim_hash['emails'][1]['type' ]).to eql('work')
                  expect(scim_hash['emails'][1]['value']).to eql('work@test.com')
                end
              end # "context 'with filter at end of path' do"

              it 'with arrays: replaces' do
                path      = [ 'emails' ]
                scim_hash = {}.with_indifferent_case_insensitive_access()

                @instance.send(
                  :from_patch_backend!,
                  nature:        'replace',
                  path:          path,
                  value:         [ { 'type' => 'work', 'value' => 'work@test.com' } ], # NOTE - to-add value is an Array (and must be)
                  altering_hash: scim_hash,
                  with_attr_map: {
                    emails: [
                      { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                      { match: 'type', with: 'work', using: { value: :work_email } },
                    ]
                  }
                )

                expect(scim_hash['emails'].size).to eql(1)
                expect(scim_hash['emails'][0]['type' ]).to eql('work')
                expect(scim_hash['emails'][0]['value']).to eql('work@test.com')
              end

              context 'when prior value already exists, and no path' do
                it 'simple value: overwrites' do
                  path      = [ 'root' ]
                  scim_hash = { 'root' => { 'userName' => 'bar', 'active' => true } }.with_indifferent_case_insensitive_access()

                  @instance.send(
                    :from_patch_backend!,
                    nature:        'replace',
                    path:          path,
                    value:         { 'active' => false }.with_indifferent_case_insensitive_access(),
                    altering_hash: scim_hash,
                    with_attr_map: {
                      userName: :user_name,
                      active:   :active
                    }
                  )

                  expect(scim_hash['root']['userName']).to eql('bar')
                  expect(scim_hash['root']['active']).to eql(false)
                end
              end
            end # context 'when value is not present' do
          end # "context 'replace' do"

          # -------------------------------------------------------------------
          # Internal: #from_patch_backend - some bespoke complex cases
          # -------------------------------------------------------------------
          #
          # I just wanted to be sure...
          #
          context 'contrived complexity' do
            before :each do
              @contrived_class = Class.new do
                def self.scim_resource_type
                  return nil
                end

                def self.scim_attributes_map
                  return {
                    complex: [
                      match: 'type',
                      with:  'type1',
                      using: {
                        data: {
                          nested: [
                            match: 'nature',
                            with:  'nature2',
                            using: {
                              info: {
                                deep: :accessor_method_is_unused_in_this_test
                              }
                            }
                          ]
                        }
                      }
                    ]
                  }
                end

                def self.scim_mutable_attributes
                  return nil
                end

                def self.scim_queryable_attributes
                  return nil
                end

                include Scimitar::Resources::Mixin
              end

              @original_hash = {
                'complex' => [
                  {
                    'type' => 'type1', # This will match the filter below
                    'data' => {
                      'nested' => [
                        {
                          'nature' => 'nature1', # This will not match
                          'info'   => [
                            { 'deep' => 'nature1deep' }
                          ]
                        },
                        {
                          'nature' => 'nature2', # This will match the filter below
                          'info'   => [
                            { 'deep' => 'nature2deep1' }
                          ]
                        },
                        {
                          'nature' => 'nature2', # This will match the filter below
                          'info'   => [
                            { 'deep' => 'nature2deep2' }
                          ]
                        },
                      ]
                    }
                  },
                  {
                    'type' => 'type1', # This will match the filter below
                    'data' => {
                      'nested' => [
                        {
                          'nature' => 'nature2', # This will match the filter below
                          'info'   => [
                            { 'deep' => 'nature2deep3' }
                          ]
                        }
                      ]
                    }
                  },
                  {
                    'type' => 'type2', # This will not match
                    'data' => {
                      'nested' => [
                        {
                          'nature' => 'nature2', # This will match the filter below, but is nested inside something that does not match
                          'info'   => [
                            { 'deep' => 'nature2deep3' }
                          ]
                        }
                      ]
                    }
                  }
                ]
              }
            end

            it 'adds across multiple deep matching points' do
              scim_hash          = @original_hash.deep_dup().with_indifferent_case_insensitive_access()
              contrived_instance = @contrived_class.new
              contrived_instance.send(
                :from_patch_backend!,
                nature:        'add',
                path:          ['complex[type eq "type1"]', 'data', 'nested[nature eq "nature2"]', 'info'],
                value:         [{ 'deeper' => 'addition' }],
                altering_hash: scim_hash,
                with_attr_map: @contrived_class.scim_attributes_map()
              )

              expect(scim_hash.dig('complex', 0, 'data', 'nested', 0, 'info').count).to eql(1) # Unchanged
              expect(scim_hash.dig('complex', 0, 'data', 'nested', 1, 'info').count).to eql(2) # One new item
              expect(scim_hash.dig('complex', 0, 'data', 'nested', 2, 'info').count).to eql(2) # One new item
              expect(scim_hash.dig('complex', 0, 'data', 'nested', 1, 'info', 1, 'deeper')).to eql('addition')
              expect(scim_hash.dig('complex', 0, 'data', 'nested', 2, 'info', 1, 'deeper')).to eql('addition')

              expect(scim_hash.dig('complex', 1, 'data', 'nested', 0, 'info').count).to eql(2) # One new item
              expect(scim_hash.dig('complex', 1, 'data', 'nested', 0, 'info', 1, 'deeper')).to eql('addition')

              expect(scim_hash.dig('complex', 2, 'data', 'nested', 0, 'info').count).to eql(1) # Unchanged
            end

            it 'replaces across multiple deep matching points' do
              scim_hash          = @original_hash.deep_dup().with_indifferent_case_insensitive_access()
              contrived_instance = @contrived_class.new
              contrived_instance.send(
                :from_patch_backend!,
                nature:        'replace',
                path:          ['complex[type eq "type1"]', 'data', 'nested[nature eq "nature2"]', 'info'],
                value:         [{ 'deeper' => 'addition' }],
                altering_hash: scim_hash,
                with_attr_map: @contrived_class.scim_attributes_map()
              )

              expect(scim_hash.dig('complex', 0, 'data', 'nested', 0, 'info').count).to eql(1) # Unchanged?
              expect(scim_hash.dig('complex', 0, 'data', 'nested', 1, 'info').count).to eql(1)
              expect(scim_hash.dig('complex', 0, 'data', 'nested', 2, 'info').count).to eql(1)
              expect(scim_hash.dig('complex', 0, 'data', 'nested', 0, 'info', 0, 'deep')).to eql('nature1deep') # Yes, unchanged.
              expect(scim_hash.dig('complex', 0, 'data', 'nested', 1, 'info', 0, 'deeper')).to eql('addition')
              expect(scim_hash.dig('complex', 0, 'data', 'nested', 2, 'info', 0, 'deeper')).to eql('addition')

              expect(scim_hash.dig('complex', 1, 'data', 'nested', 0, 'info').count).to eql(1)
              expect(scim_hash.dig('complex', 1, 'data', 'nested', 0, 'info', 0, 'deeper')).to eql('addition')

              expect(scim_hash.dig('complex', 2, 'data', 'nested', 0, 'info').count).to eql(1) # Unchanged
              expect(scim_hash.dig('complex', 2, 'data', 'nested', 0, 'info', 0, 'deep')).to eql('nature2deep3') # Unchanged
            end

            it 'removes via clearing to "nil" or empty Array across multiple deep matching points' do
              scim_hash          = @original_hash.deep_dup().with_indifferent_case_insensitive_access()
              contrived_instance = @contrived_class.new
              contrived_instance.send(
                :from_patch_backend!,
                nature:        'remove',
                path:          ['complex[type eq "type1"]', 'data', 'nested[nature eq "nature2"]', 'info'],
                value:         nil,
                altering_hash: scim_hash,
                with_attr_map: @contrived_class.scim_attributes_map()
              )

              expect(scim_hash.dig('complex', 0, 'data', 'nested', 0, 'info').count).to eql(1) # Unchanged
              expect(scim_hash.dig('complex', 0, 'data', 'nested', 1, 'info')).to eql([])
              expect(scim_hash.dig('complex', 0, 'data', 'nested', 2, 'nature')).to be_present
              expect(scim_hash.dig('complex', 0, 'data', 'nested', 1, 'info')).to eql([])
              expect(scim_hash.dig('complex', 0, 'data', 'nested', 2, 'nature')).to be_present

              expect(scim_hash.dig('complex', 1, 'data', 'nested', 0, 'info')).to eql([])
              expect(scim_hash.dig('complex', 1, 'data', 'nested', 0, 'nature')).to be_present

              expect(scim_hash.dig('complex', 2, 'data', 'nested', 0, 'info').count).to eql(1) # Unchanged
              expect(scim_hash.dig('complex', 2, 'data', 'nested', 0, 'info', 0, 'deep')).to eql('nature2deep3') # Unchanged
            end
          end # "context 'contrived complexity' do"

          # -------------------------------------------------------------------
          # Internal: #from_patch_backend - error handling
          # -------------------------------------------------------------------
          #
          context 'with bad patches, raises errors' do
            it 'for unsupported filters' do
              path      = [ 'emails[type ne "work" and value ne "hello@test.com"', 'value' ]
              scim_hash = {
                'emails' => [
                  {
                    'type' => 'work',
                    'value' => 'work_1@test.com'
                  },
                  {
                    'type' => 'work',
                    'value' => 'work_2@test.com'
                  }
                ]
              }.with_indifferent_case_insensitive_access()

              expect do
                @instance.send(
                  :from_patch_backend!,
                  nature:        'replace',
                  path:          path,
                  value:         'ignored',
                  altering_hash: scim_hash,
                  with_attr_map: {
                    emails: [
                      { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                      { match: 'type', with: 'work', using: { value: :work_email } },
                    ]
                  }
                )
              end.to raise_error(Scimitar::ErrorResponse) { |e| expect(e.as_json['scimType']).to eql('invalidSyntax') }
            end

            it 'when filters are specified for non-array types' do
              path      = [ 'userName[type eq "work"]', 'value' ]
              scim_hash = {
                'userName' => '1234'
              }.with_indifferent_case_insensitive_access()

              expect do
                @instance.send(
                  :from_patch_backend!,
                  nature:        'replace',
                  path:          path,
                  value:         'ignored',
                  altering_hash: scim_hash,
                  with_attr_map: { userName: :user_name }
                )
              end.to raise_error(Scimitar::ErrorResponse) { |e| expect(e.as_json['scimType']).to eql('invalidSyntax') }
            end

            it 'when a filter tries to match an array which does not contain Hashes' do
              path      = [ 'emails[type eq "work"]', 'value' ]
              scim_hash = {
                'emails' => [
                  'work_1@test.com',
                  'work_2@test.com',
                ]
              }.with_indifferent_case_insensitive_access()

              expect do
                @instance.send(
                  :from_patch_backend!,
                  nature:        'replace',
                  path:          path,
                  value:         'ignored',
                  altering_hash: scim_hash,
                  with_attr_map: {
                    emails: [
                      { match: 'type', with: 'home', using: { value: :home_email, primary: true } },
                      { match: 'type', with: 'work', using: { value: :work_email } },
                    ]
                  }
                )
              end.to raise_error(Scimitar::ErrorResponse) { |e| expect(e.as_json['scimType']).to eql('invalidSyntax') }
            end
          end # context 'with bad patches, raises errors' do
        end # "context '#from_patch_backend!' do"
      end # "context 'internal unit tests' do"

      # -------------------------------------------------------------------
      # Public
      # -------------------------------------------------------------------
      #
      context 'public interface' do
        shared_examples 'a patcher' do | force_upper_case: |
          it 'gives the user a comprehensible error when operations are missing' do
            patch = { 'schemas' => ['urn:ietf:params:scim:api:messages:2.0:PatchOp'] }

            expect do
              @instance.from_scim_patch!(patch_hash: patch)
            end.to raise_error Scimitar::InvalidSyntaxError, "Missing PATCH \"operations\""
          end

          it 'which updates simple values' do
            @instance.update!(username: 'foo')

            path = 'userName'
            path = path.upcase if force_upper_case

            patch = {
              'schemas'    => ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              'Operations' => [
                {
                  'op'    => 'replace',
                  'path'  => path,
                  'value' => '1234'
                }
              ]
            }

            @instance.from_scim_patch!(patch_hash: patch)
            expect(@instance.username).to eql('1234')
          end

          it 'which updates nested values using root syntax' do
            @instance.update!(first_name: 'Foo', last_name: 'Bar')

            path = 'name.givenName'
            path = path.upcase if force_upper_case

            patch = {
              'schemas'    => ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              'Operations' => [
                {
                  'op'    => 'replace',
                  'value' => {
                    path => 'Baz'
                  }
                }
              ]
            }

            @instance.from_scim_patch!(patch_hash: patch)
            expect(@instance.first_name).to eql('Baz')
          end

          it 'which updates nested values' do
            @instance.update!(first_name: 'Foo', last_name: 'Bar')

            path = 'name.givenName'
            path = path.upcase if force_upper_case

            patch = {
              'schemas'    => ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              'Operations' => [
                {
                  'op'    => 'replace',
                  'path'  => path,
                  'value' => 'Baz'
                }
              ]
            }

            @instance.from_scim_patch!(patch_hash: patch)
            expect(@instance.first_name).to eql('Baz')
          end

          # Note odd ":" separating schema ID from first attribute, although
          # the nature of JSON rendering / other payloads might lead you to
          # expect a "." as with any other path component.
          #
          # Note the ":" separating the schema ID (URN) from the attribute.
          # The nature of JSON rendering / other payloads might lead you to
          # expect a "." as with any complex types, but that's not the case;
          # see https://tools.ietf.org/html/rfc7644#section-3.10, or
          # https://tools.ietf.org/html/rfc7644#section-3.5.2 of which in
          # particular, https://tools.ietf.org/html/rfc7644#page-35.
          #
          it 'which updates attributes defined by extension schema' do
            @instance.update!(department: 'SOMEDPT')

            path = 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User:department'
            path = path.upcase if force_upper_case

            patch = {
              'schemas'    => ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              'Operations' => [
                {
                  'op'    => 'replace',
                  'path'  => path,
                  'value' => 'OTHERDPT'
                }
              ]
            }

            @instance.from_scim_patch!(patch_hash: patch)
            expect(@instance.department).to eql('OTHERDPT')
          end

          it 'which updates with filter match' do
            @instance.update!(work_email_address: 'work@test.com', home_email_address: 'home@test.com')

            filter_prefix = 'emails[type'
            filter_prefix = filter_prefix.upcase if force_upper_case

            patch = {
              'schemas'    => ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              'Operations' => [
                {
                  'op'    => 'replace',
                  'path'  => filter_prefix + ' eq "work"].value',
                  'value' => 'replaced@test.com'
                }
              ]
            }

            @instance.from_scim_patch!(patch_hash: patch)
            expect(@instance.work_email_address).to eql('replaced@test.com')
            expect(@instance.home_email_address).to eql('home@test.com')
          end

          it 'which appends e-mails' do
            @instance.update!(work_email_address: 'work@test.com')

            filter_prefix = 'emails[type'
            filter_prefix = filter_prefix.upcase if force_upper_case

            patch = {
              'schemas'    => ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              'Operations' => [
                {
                  'op'    => 'add',
                  'path'  => filter_prefix + ' eq "home"].value',
                  'value' => 'home@test.com'
                }
              ]
            }

            @instance.from_scim_patch!(patch_hash: patch)
            expect(@instance.work_email_address).to eql('work@test.com')
            expect(@instance.home_email_address).to eql('home@test.com')
          end

          it 'which removes e-mails' do
            @instance.update!(work_email_address: 'work@test.com', home_email_address: 'home@test.com')

            filter_prefix = 'emails[type'
            filter_prefix = filter_prefix.upcase if force_upper_case

            patch = {
              'schemas'    => ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              'Operations' => [
                {
                  'op'   => 'remove',
                  'path' => filter_prefix + ' eq "home"].value',
                }
              ]
            }

            @instance.from_scim_patch!(patch_hash: patch)
            expect(@instance.work_email_address).to eql('work@test.com')
            expect(@instance.home_email_address).to be_nil
          end

          it 'which can patch the whole object' do
            @instance.update!(username: 'foo')

            hash = {
              'userName' => '1234',
              'name' => {
                'givenName' => 'Bar'
              }
            }

            hash = spec_helper_hupcase(hash) if force_upper_case

            patch = {
              'schemas'    => ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              'Operations' => [
                {
                  'op'    => 'replace',
                  'value' => hash
                }
              ]
            }

            @instance.from_scim_patch!(patch_hash: patch)
            expect(@instance.username).to eql('1234')
            expect(@instance.first_name).to eql('Bar')
          end
        end # "shared_examples 'a patcher' do | force_upper_case: |"

        context 'using schema-matched case' do
          it_behaves_like 'a patcher', force_upper_case: false
        end # "context 'using schema-matched case' do"

        context 'using upper case' do
          it_behaves_like 'a patcher', force_upper_case: true

          it 'treats operation types as case-insensitive' do
            @instance.update!(username: 'foo')

            patch = {
              'schemas'    => ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              'Operations' => [
                {
                  'op'    => 'REPLACE', # Note upper case
                  'path'  => 'userName',
                  'value' => '1234'
                }
              ]
            }

            @instance.from_scim_patch!(patch_hash: patch)
            expect(@instance.username).to eql('1234')
          end
        end # "context 'using upper case' do"

        context 'with errors' do
          it 'complains about bad operation types' do
            patch = {
              'schemas'    => ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              'Operations' => [
                {
                  'op'    => 'invalidop',
                  'path'  => 'userName',
                  'value' => '1234'
                }
              ]
            }

            expect { @instance.from_scim_patch!(patch_hash: patch) }.to raise_error(Scimitar::ErrorResponse) do |e|
              expect(e.as_json['scimType']).to eql('invalidSyntax')
              expect(e.as_json[:detail   ]).to include('invalidop')
            end
          end

          it 'complains about a missing target for "remove" operations' do
            patch = {
              'schemas'    => ['urn:ietf:params:scim:api:messages:2.0:PatchOp'],
              'Operations' => [
                {
                  'op' => 'remove'
                }
              ]
            }

            expect { @instance.from_scim_patch!(patch_hash: patch) }.to raise_error(Scimitar::ErrorResponse) do |e|
              expect(e.as_json['scimType']).to eql('noTarget')
            end
          end
        end # "context 'with errors' do"
      end # "context 'public interface' do"
    end # "context '#from_scim_patch!' do"
  end # "context 'with good class definitons' do"
end # "RSpec.describe Scimitar::Resources::Mixin do"
