module Scimitar

  # Scimitar general configuration.
  #
  # See config/initializers/scimitar.rb for more information.
  #
  class EngineConfiguration
    include ActiveModel::Model

    attr_accessor(
      :uses_defaults,
      :basic_authenticator,
      :token_authenticator,
      :custom_authenticator,
      :custom_request_sanitizer,
      :application_controller_mixin,
      :exception_reporter,
      :optional_value_fields_required,
      :render_mapped_nil_values_in_response,
      :schema_list_from_attribute_mappings,
    )

    def initialize(attributes = {})
      @uses_defaults = attributes.empty?

      # Set defaults that may be overridden by the initializer.
      #
      defaults = {
        optional_value_fields_required:       true,
        render_mapped_nil_values_in_response: true,
        schema_list_from_attribute_mappings:  []
      }

      super(defaults.merge(attributes))
    end

  end
end
