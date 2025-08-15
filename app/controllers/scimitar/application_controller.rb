module Scimitar
  class ApplicationController < ActionController::Base

    rescue_from StandardError,                                with: :handle_unexpected_error
    rescue_from ActionDispatch::Http::Parameters::ParseError, with: :handle_bad_json_error # Via "ActionDispatch::Request.parameter_parsers" block in lib/scimitar/engine.rb
    rescue_from Scimitar::ErrorResponse,                      with: :handle_scim_error

    before_action :require_scim
    before_action :add_mandatory_response_headers
    before_action :authenticate

    # =========================================================================
    # PROTECTED INSTANCE METHODS
    # =========================================================================
    #
    protected

      # You can use:
      #
      #    rescue_from SomeException, with: :handle_resource_not_found
      #
      # ...to "globally" invoke this handler if you wish.
      #
      # +exception+:: Exception instance, used for a configured error reporter
      #               via #handle_scim_error (if present).
      #
      def handle_resource_not_found(exception)
        handle_scim_error(NotFoundError.new(params[:id]), exception)
      end

      # This base controller uses:
      #
      #    rescue_from Scimitar::ErrorResponse, with: :handle_scim_error
      #
      # ...to "globally" invoke this handler for all Scimitar errors (including
      # subclasses).
      #
      # Mandatory parameters are:
      #
      # +error_response+:: Scimitar::ErrorResponse (or subclass) instance.
      #
      # Optional parameters are:
      #
      # *exception+:: If a Ruby exception was the reason this method is being
      #               called, pass it here. Any configured exception reporting
      #               mechanism will be invoked with the given parameter.
      #               Otherwise, the +error_response+ value is reported.
      #
      def handle_scim_error(error_response, exception = error_response)
        unless Scimitar.engine_configuration.exception_reporter.nil?
          Scimitar.engine_configuration.exception_reporter.call(exception)
        end

        render json: error_response, status: error_response.status
      end

      # This base controller uses:
      #
      #     rescue_from ActionDispatch::Http::Parameters::ParseError, with: :handle_bad_json_error
      #
      # ...to "globally" handle JSON errors implied by parse errors raised via
      # the "ActionDispatch::Request.parameter_parsers" block in
      # lib/scimitar/engine.rb.
      #
      # +exception+:: Exception instance.
      #
      def handle_bad_json_error(exception)
        handle_scim_error(ErrorResponse.new(status: 400, detail: "Invalid JSON - #{exception.message}"), exception)
      end

      # This base controller uses:
      #
      #     rescue_from StandardError, with: :handle_unexpected_error
      #
      # ...to "globally" handle 500-style cases with a SCIM response.
      #
      # +exception+:: Exception instance.
      #
      def handle_unexpected_error(exception)
        Rails.logger.error("#{exception.message}\n#{exception.backtrace}")
        handle_scim_error(ErrorResponse.new(status: 500, detail: exception.message), exception)
      end

    # =========================================================================
    # PRIVATE INSTANCE METHODS
    # =========================================================================
    #
    private

      # Tries to be permissive in what it receives - ".scim" extensions or a
      # Content-Type header (or both) lead to both being set up for the inbound
      # request and subclass processing.
      #
      def require_scim
        scim_mime_type = Mime::Type.lookup_by_extension(:scim).to_s

        if request.media_type.nil? || request.media_type.empty?
          request.format = :scim
          request.headers['CONTENT_TYPE'] = scim_mime_type
        elsif request.media_type.downcase == scim_mime_type
          request.format = :scim
        elsif request.format == :scim
          request.headers['CONTENT_TYPE'] = scim_mime_type
        else
          handle_scim_error(ErrorResponse.new(status: 406, detail: "Only #{scim_mime_type} type is accepted."))
        end
      end

      def add_mandatory_response_headers

        # https://tools.ietf.org/html/rfc7644#section-2
        #
        #   "...a SCIM service provider SHALL indicate supported HTTP
        #   authentication schemes via the "WWW-Authenticate" header."
        #
        # Rack may not handle an attempt to set two instances of the header and
        # there is much debate on how to specify multiple methods in one header
        # so we just let Token override Basic (since Token is much stronger, or
        # at least has the potential to do so) if that's how Rack handles it.
        #
        # https://stackoverflow.com/questions/10239970/what-is-the-delimiter-for-www-authenticate-for-multiple-schemes
        #
        response.set_header('WWW-Authenticate', 'Basic' ) if Scimitar.engine_configuration.basic_authenticator.present?
        response.set_header('WWW-Authenticate', 'Bearer') if Scimitar.engine_configuration.token_authenticator.present?

        # No matter what a caller might request via headers, the only content
        # type we can ever respond with is JSON-for-SCIM.
        #
        response.set_header('Content-Type', "#{Mime::Type.lookup_by_extension(:scim)}; charset=utf-8")
      end

      def authenticate
        unless authenticated?
          handle_scim_error(Scimitar::AuthenticationError.new) unless self.performed?
        end
      end

      def authenticated?
        result = if Scimitar.engine_configuration.basic_authenticator.present?
          authenticate_with_http_basic do |username, password|
            instance_exec(username, password, &Scimitar.engine_configuration.basic_authenticator)
          end
        elsif Scimitar.engine_configuration.token_authenticator.present?
          authenticate_with_http_token do |token, options|
            instance_exec(token, options, &Scimitar.engine_configuration.token_authenticator)
          end
        elsif Scimitar.engine_configuration.custom_authenticator.present?
          instance_exec(&Scimitar.engine_configuration.custom_authenticator)
        end

        return result
      end

    if Scimitar.engine_configuration.application_controller_mixin
      include Scimitar.engine_configuration.application_controller_mixin
    end
  end
end
