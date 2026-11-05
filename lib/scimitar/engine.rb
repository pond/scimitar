require 'rails/engine'

module Scimitar
  class Engine < ::Rails::Engine
    isolate_namespace Scimitar

    config.autoload_once_paths = %W(
      #{root}/app/controllers
      #{root}/app/models
    )

    Mime::Type.register 'application/scim+json', :scim

    parsers = ActionDispatch::Request.parameter_parsers
    updated_parsers = parsers.frozen? ? parsers.dup : parsers
    updated_parsers[Mime::Type.lookup('application/scim+json').symbol] = lambda do |body|
      JSON.parse(body)
    end
    ActionDispatch::Request.parameter_parsers = updated_parsers if parsers.frozen?

    # Return an Array of all supported default and custom resource classes.
    # See also :add_custom_resource and :set_default_resources.
    #
    def self.resources
      self.default_resources() + self.custom_resources()
    end

    # Returns a flat array of instances of all resource schema included in the
    # resource classes returned by ::resources.
    #
    def self.schemas
      self.resources().map(&:schemas).flatten.uniq.map(&:new)
    end

    # Returns the list of custom resources, if any.
    #
    def self.custom_resources
      @custom_resources ||= []
    end

    # Can be used to add a new resource type which is not provided by the gem.
    # For example:
    #
    #     module Scim
    #       module Resources
    #         class ShinyResource < Scimitar::Resources::Base
    #           set_schema Scim::Schema::Shiny
    #
    #           def self.endpoint
    #             "/Shinies"
    #           end
    #         end
    #       end
    #     end
    #
    #     Scimitar::Engine.add_custom_resource Scim::Resources::ShinyResource
    #
    def self.add_custom_resource(resource)
      self.custom_resources() << resource
    end

    # Resets the resource list to default. This is really only intended for use
    # during testing, to avoid one test polluting another.
    #
    def self.reset_custom_resources
      @custom_resources = []
    end

    # Returns the default resources added in this gem - by default, these are:
    #
    # * Scimitar::Resources::User
    # * Scimitar::Resources::Group
    #
    # ...but if an implementation does not e.g. support Group, it can
    # be overridden via ::set_default_resources to help with service
    # auto-discovery.
    #
    def self.default_resources
      @standard_default_resources = [ Resources::User, Resources::Group ]
      @default_resources        ||= @standard_default_resources.dup()
    end

    # Override the resources returned by ::default_resources.
    #
    # +resource_array+:: An Array containing one or both of
    #                    Scimitar::Resources::User and/or
    #                    Scimitar::Resources::Group, and nothing else.
    #
    def self.set_default_resources(resource_array)
      self.default_resources()
      unrecognised_resources = resource_array - @standard_default_resources

      if unrecognised_resources.any?
        raise "Scimitar::Engine.set_default_resources: Only #{@standard_default_resources.map(&:name).join(', ')} are supported"
      elsif resource_array.empty?
        raise 'Scimitar::Engine.set_default_resources: At least one resource must be given'
      end

      @default_resources = resource_array
    end

    # Resets the default resource list. This is really only intended for use
    # during testing, to avoid one test polluting another.
    #
    def self.reset_default_resources
      self.default_resources()
      @default_resources = @standard_default_resources
    end

  end
end
