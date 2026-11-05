require 'spec_helper'
require 'open3'

RSpec.describe Scimitar::Engine do
  before :each do
    allow_any_instance_of(Scimitar::ApplicationController).to receive(:authenticated?).and_return(true)
  end

  context 'parameter parser' do

    [false, true].each do |frozen_registry|
      it "registers with a #{frozen_registry ? 'frozen' : 'mutable'} parser registry" do
        skip 'Rails freezes the parser registry' if !frozen_registry && ActionDispatch::Request.parameter_parsers.frozen?

        output, errors, status = Open3.capture3(RbConfig.ruby, '-Ilib', '-e', <<~RUBY)
          require 'action_controller/railtie'
          require 'stringio'
          registry = ActionDispatch::Request.parameter_parsers
          registry.freeze if #{frozen_registry}
          require 'scimitar'
          registry[:scim] = ->(body) { { 'userName' => 'configured' } } unless #{frozen_registry}
          body = '{"userName":"original"}'
          request = ActionDispatch::Request.new(
            'REQUEST_METHOD' => 'POST', 'CONTENT_TYPE' => 'application/scim+json',
            'CONTENT_LENGTH' => body.bytesize.to_s, 'rack.input' => StringIO.new(body)
          )
          puts JSON.generate(request.request_parameters.to_h)
        RUBY

        expect(status.success?).to eql(true), errors
        expect(JSON.parse(output)).to eql('userName' => frozen_registry ? 'original' : 'configured')
      end
    end

    # "params" given here as a String, expecting the engine's custom parser to
    # decode it for us.
    #
    it 'decodes simple JSON', type: :model do
      post '/Users.scim', params: '{"userName": "foo"}', headers: { 'CONTENT_TYPE' => 'application/scim+json' }

      expect(response.status).to eql(201)
      expect(JSON.parse(response.body)['userName']).to eql('foo')
    end

    it 'decodes nested JSON', type: :model do
      post '/Users.scim', params: '{"userName": "foo", "name": {"givenName": "bar", "familyName": "baz"}}', headers: { 'CONTENT_TYPE' => 'application/scim+json' }

      expect(response.status).to eql(201)
      expect(JSON.parse(response.body)['userName']).to eql('foo')
      expect(JSON.parse(response.body)['name']['givenName']).to eql('bar')
      expect(JSON.parse(response.body)['name']['familyName']).to eql('baz')
    end

    it 'is case insensitive at the top level', type: :model do
      post '/Users.scim', params: '{"USERNAME": "foo"}', headers: { 'CONTENT_TYPE' => 'application/scim+json' }

      expect(response.status).to eql(201)
      expect(JSON.parse(response.body)['userName']).to eql('foo')
    end

    it 'is case insensitive in nested levels', type: :model do
      post '/Users.scim', params: '{"USERNAME": "foo", "NAME": {"GIVENNAME": "bar", "FAMILYNAME": "baz"}}', headers: { 'CONTENT_TYPE' => 'application/scim+json' }

      expect(response.status).to eql(201)
      expect(JSON.parse(response.body)['userName']).to eql('foo')
      expect(JSON.parse(response.body)['name']['givenName']).to eql('bar')
      expect(JSON.parse(response.body)['name']['familyName']).to eql('baz')
    end
  end # "context 'parameter parser' do"

  # These are unit tests rather than request tests; seems like a reasonable
  # place to put them in the absence of a standardised RSpec "engine" location.
  #
  context 'engine unit tests' do
    around :each do | example |
      license_schema = Class.new(Scimitar::Schema::Base) do
        def initialize(options = {})
          super(name: 'License', id: self.class.id(), description: 'Represents a License')
        end
        def self.id; 'urn:ietf:params:scim:schemas:license'; end
        def self.scim_attributes; []; end
      end

      @license_resource = Class.new(Scimitar::Resources::Base) do
        self.set_schema(license_schema)
        def self.endpoint; '/License'; end
      end

      example.run()
    ensure
      Scimitar::Engine.reset_default_resources()
      Scimitar::Engine.reset_custom_resources()
    end

    context '::resources, :add_custom_resource, ::set_default_resources' do
      it 'returns default resources' do
        expect(Scimitar::Engine.resources()).to match_array([Scimitar::Resources::User, Scimitar::Resources::Group])
      end

      it 'includes custom resources' do
        Scimitar::Engine.add_custom_resource(@license_resource)
        expect(Scimitar::Engine.resources()).to match_array([Scimitar::Resources::User, Scimitar::Resources::Group, @license_resource])
      end

      it 'notes changes to defaults' do
        Scimitar::Engine.set_default_resources([Scimitar::Resources::User])
        expect(Scimitar::Engine.resources()).to match_array([Scimitar::Resources::User])
      end

      it 'notes changes to defaults with custom resources added' do
        Scimitar::Engine.set_default_resources([Scimitar::Resources::User])
        Scimitar::Engine.add_custom_resource(@license_resource)
        expect(Scimitar::Engine.resources()).to match_array([Scimitar::Resources::User, @license_resource])
      end

      it 'rejects bad defaults' do
        expect {
          Scimitar::Engine.set_default_resources([@license_resource])
        }.to raise_error('Scimitar::Engine.set_default_resources: Only Scimitar::Resources::User, Scimitar::Resources::Group are supported')
      end

      it 'rejects empty defaults' do
        expect {
          Scimitar::Engine.set_default_resources([])
        }.to raise_error('Scimitar::Engine.set_default_resources: At least one resource must be given')
      end
    end # "context '::resources, :add_custom_resource, ::set_default_resources' do"

    context '#schemas' do
      it 'returns schema instances from ::resources' do
        expect(Scimitar::Engine).to receive(:resources).and_return([Scimitar::Resources::User, @license_resource])

        schema_instances = Scimitar::Engine.schemas()
        schema_classes   = schema_instances.map(&:class)

        expect(schema_classes).to match_array([
          Scimitar::Schema::User,
          ScimSchemaExtensions::User::Enterprise,
          ScimSchemaExtensions::User::Manager,
          @license_resource.schemas.first
        ])
      end
    end # "context '#schemas' do"
  end # "context 'engine unit tests' do"
end
