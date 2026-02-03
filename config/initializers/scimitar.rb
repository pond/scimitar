# SCIMITAR CONFIGURATION
#
# For supporting information and rationale, please see README.md.

Rails.application.config.to_prepare do # (required for >= Rails 7 / Zeitwerk)

  # ===========================================================================
  # SERVICE PROVIDER CONFIGURATION
  # ===========================================================================
  #
  # This is a Ruby abstraction over a SCIM entity that declares the
  # capabilities supported by a particular implementation.
  #
  # Typically this is used to declare parts of the standard unsupported, if you
  # don't need them and don't want to provide subclass support.
  #
  Scimitar.service_provider_configuration = Scimitar::ServiceProviderConfiguration.new({

    # See https://tools.ietf.org/html/rfc7643#section-8.5 for properties.
    #
    # See Gem file 'app/models/scimitar/service_provider_configuration.rb'
    # for defaults. Define Hash keys here that override defaults; e.g. to
    # declare that filters are not supported so that calling clients shouldn't
    # use them:
    #
    #   filter: Scimitar::Supported.unsupported

  })

  # ===========================================================================
  # ENGINE CONFIGURATION
  # ===========================================================================
  #
  # This is where you provide callbacks for things like authorisation or mixins
  # that get included into all Scimitar-derived controllers (for things like
  # before-actions that apply to all Scimitar controller-based routes).
  #
  Scimitar.engine_configuration = Scimitar::EngineConfiguration.new({

    # If you have filters you want to run for any Scimitar action/route, you
    # can define them here. You can also override any shared controller methods
    # here. For example, you might use a before-action to set up some
    # multi-tenancy related state, skip Rails CSRF token verification, or
    # customise how Scimitar generates URLs:
    #
    #     application_controller_mixin: Module.new do
    #       def self.included(base)
    #         base.class_eval do
    #
    #           # Anything here is written just as you'd write it at the top of
    #           # one of your controller classes, but it gets included in all
    #           # Scimitar classes too.
    #
    #           skip_before_action    :verify_authenticity_token
    #           prepend_before_action :setup_some_kind_of_multi_tenancy_data
    #         end
    #       end
    #
    #       def scim_schemas_url(options)
    #         super(custom_param: 'value', **options)
    #       end
    #     end, # ...other configuration entries might follow...

    # If you want to support username/password authentication:
    #
    #     basic_authenticator: Proc.new do | username, password |
    #       # Check username/password and return 'true' if valid, else 'false'.
    #     end, # ...other configuration entries might follow...
    #
    # The 'username' and 'password' parameters come from Rails:
    #
    #   https://api.rubyonrails.org/classes/ActionController/HttpAuthentication/Basic.html
    #   https://api.rubyonrails.org/classes/ActionController/HttpAuthentication/Basic/ControllerMethods.html#method-i-authenticate_with_http_basic

    # If you want to support HTTP bearer token (OAuth-style) authentication:
    #
    #     token_authenticator: Proc.new do | token, options |
    #       # Check token and return 'true' if valid, else 'false'.
    #     end, # ...other configuration entries might follow...
    #
    # The 'token' and 'options' parameters come from Rails:
    #
    #   https://api.rubyonrails.org/classes/ActionController/HttpAuthentication/Token.html
    #   https://api.rubyonrails.org/classes/ActionController/HttpAuthentication/Token/ControllerMethods.html#method-i-authenticate_with_http_token
    #
    # Note that both basic and token authentication can be declared, with the
    # parameters in the inbound HTTP request determining which is invoked.

    # If you want to support a custom authenticfation method:
    #
    #     custom_authenticator: Proc.new do
    #       # Custom code here. don't forget to set a WWW-Authenticate header:
    #       response.headers['WWW-Authenticate'] = '...something...'
    #       # ...and evaluate to 'true' for success or 'false' for failure.
    #     end
    #
    # If a basic and/or token authenticator has also been defined, then they're
    # called first. The code will cascade through trying each and only call a
    # custom authenticator if other mechanisms fail to authenticate.

    # Scimitar rescues certain error cases and exceptions, in order to return a
    # JSON response to the API caller. If you want exceptions to also be
    # reported to a third party system such as sentry.io or raygun.com, you can
    # configure a Proc to do so. It is passed a Ruby exception subclass object.
    # The Proc is called via 'instance_exec' in the controller context, so you
    # have access to things like 'request', 'params' and 'action_name'. For
    # example, a minimal sentry.io reporter might do this:
    #
    #     exception_reporter: Proc.new do | exception |
    #       Sentry.capture_exception(exception)
    #     end
    #
    # You will still need to configure your reporting system according to its
    # documentation (e.g. via a Rails "config/initializers/<foo>.rb" file).

    # Scimilar treats "VDTP" (Value, Display, Type, Primary) attribute values,
    # used for e.g. e-mail addresses or phone numbers, as required by default.
    # If you encounter a service which calls these with e.g. "null" value data,
    # you can configure all values to be optional. You'll need to deal with
    # whatever that means for you receiving system in your model code.
    #
    #     optional_value_fields_required: false

    # The SCIM standard `/Schemas` endpoint lists, by default, all known schema
    # definitions with the mutabilty (read-write, read-only, write-only) state
    # described by those definitions, and includes all defined attributes. For
    # user-defined schema, this will typically exactly match your underlying
    # mapped attribute and model capability - it wouldn't make sense to define
    # your own schema that misrepresented the implementation! For core SCIM RFC
    # schema, though, you might want to only list actually mapped attributes.
    # Further, if you happen to have a non-compliant implementation especially
    # in relation to mutability of some attributes, you may want to report that
    # accurately in the '/Schemas' list, for auto-discovery purposes. To switch
    # to a significantly slower but more accurate render method for the list,
    # driven by your resource subclasses and their attribute maps, set:
    #
    #     schema_list_from_attribute_mappings: [...array...]
    #
    # ...where you provide an Array of *models*, your classes that include the
    # Scimitar::Resources::Mixin module and, therefore, define an attribute map
    # translating SCIM schema attributes into actual implemented data. These
    # must *uniquely* describe, via the Scimitar resources they each declare in
    # their Scimitar::Resources::Mixin::scim_resource_type implementation, the
    # set of schemas and extended schemas you want to render. Should resources
    # share schema, the '/Schemas' endpoint will fail since it cannot determine
    # which model attribute map it should use and it needs the map in order to
    # resolve the differences (if any) between what the schema might say, and
    # what the actual underlying model supports.
    #
    # It is further _very_ _strongly_ _recommended_ that, for any
    # +scim_attributes_map+ containing a collection which has "list:" key (for
    # an associative array of zero or more entities; the Groups to which a User
    # might belong is a good example) then you should also specify the "class:"
    # key, giving the class used for objects in that associated collection. The
    # class *must* include Scimitar::Resources::Mixin, since its own attribute
    # map is consulted in order to render the part of the schema describing
    # those associated properties in the owning resource. If you don't do this,
    # and if you're using ActiveRecord, then Scimitar attempts association
    # reflection to determine the collection class - but that's more fragile
    # than just being told the exact class in the attribute map. No matter how
    # this class is determined, though, it must be possible to create a simple
    # instance with +new+ and no parameters, since that's needed in order to
    # call Scimitar::Resources::Mixin#scim_mutable_attributes.
  })

end
