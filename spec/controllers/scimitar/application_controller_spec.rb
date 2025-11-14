require 'spec_helper'

RSpec.describe Scimitar::ApplicationController do
  context 'basic authentication' do
    before do
      Scimitar.engine_configuration = Scimitar::EngineConfiguration.new(
        basic_authenticator: Proc.new do | username, password |
          username == 'A' && password == 'B'
        end
      )
    end

    controller do
      def index
        render json: { 'message' => 'cool, cool!' }, format: :scim
      end
    end

    it 'renders success when valid creds are given' do
      request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials('A', 'B')

      get :index, params: { format: :scim }
      expect(response).to be_ok
      expect(JSON.parse(response.body)).to eql({ 'message' => 'cool, cool!' })
      expect(response.headers['WWW-Authenticate']).to eql('Basic')
    end

    it 'renders failure with bad password' do
      request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials('A', 'C')

      get :index, params: { format: :scim }
      expect(response).not_to be_ok
    end

    it 'renders failure with bad user name' do
      request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials('C', 'B')

      get :index, params: { format: :scim }
      expect(response).not_to be_ok
    end

    it 'renders failure with bad user name and password' do
      request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials('C', 'D')

      get :index, params: { format: :scim }
      expect(response).not_to be_ok
    end

    it 'renders failure with blank password' do
      request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials('A', '')

      get :index, params: { format: :scim }
      expect(response).not_to be_ok
    end

    it 'renders failure with missing header' do
      get :index, params: { format: :scim }
      expect(response).not_to be_ok
    end
  end


  context 'token authentication' do
    before do
      Scimitar.engine_configuration = Scimitar::EngineConfiguration.new(
        token_authenticator: Proc.new do | token, options |
          token == 'A'
        end
      )
    end

    controller do
      def index
        render json: { 'message' => 'cool, cool!' }, format: :scim
      end
    end

    it 'renders success when valid creds are given' do
      request.env['HTTP_AUTHORIZATION'] = 'Bearer A'

      get :index, params: { format: :scim }
      expect(response).to be_ok
      expect(JSON.parse(response.body)).to eql({ 'message' => 'cool, cool!' })
      expect(response.headers['WWW-Authenticate']).to eql('Bearer')
    end

    it 'renders failure with bad token' do
      request.env['HTTP_AUTHORIZATION'] = 'Bearer Invalid'

      get :index, params: { format: :scim }
      expect(response).not_to be_ok
    end

    it 'renders failure with blank token' do
      request.env['HTTP_AUTHORIZATION'] = 'Bearer'

      get :index, params: { format: :scim }
      expect(response).not_to be_ok
    end

    it 'renders failure with missing header' do
      get :index, params: { format: :scim }
      expect(response).not_to be_ok
    end
  end

  context 'custom authentication, using Warden as an example' do
    include Warden::Test::Helpers

    controller do
      def index
        render json: { 'message' => 'cool, cool!' }, format: :scim
      end
    end

    context 'with standard 401 handling' do
      before do
        Scimitar.engine_configuration = Scimitar::EngineConfiguration.new(
          custom_authenticator: Proc.new do
            catch(:warden) do
              response.headers['WWW-Authenticate'] = 'SomeOtherValidScheme'

              warden = request.env['warden']
              warden.authenticate!(scope: :scim_v2)
              true
            end or false
          end
        )
      end

      context 'when authentication suceeds' do
        it 'renders "success"' do
          expect(warden).to receive(:authenticate!).and_return("A User instance or similar") # ('warden' is the proxy provided by the warden-rspec-rails gem)

          get :index, params: { format: :scim }

          expect(response).to be_ok
          expect(JSON.parse(response.body)).to eql({ 'message' => 'cool, cool!' })
          expect(response.headers['WWW-Authenticate']).to eql('SomeOtherValidScheme') # Proves the custom block ran
        end
      end

      context 'when authentication fails' do # We're kinda just verifying the README.md example code here!
        it 'renders 401' do
          expect(warden).to receive(:authenticate!) { throw(:warden) } # ('warden' is the proxy provided by the warden-rspec-rails gem)

          get :index, params: { format: :scim }

          expect(response).to have_http_status(:unauthorized)
          expect(response.headers['WWW-Authenticate']).to eql('SomeOtherValidScheme') # Proves the custom block ran

          parsed_body = JSON.parse(response.body)

          expect(parsed_body).to include('schemas' => ['urn:ietf:params:scim:api:messages:2.0:Error'])
          expect(parsed_body).to include('detail' => 'Requires authentication')
          expect(parsed_body).to include('status' => '401')
        end
      end
    end

    context 'with custom error handling' do
      before do
        Scimitar.engine_configuration = Scimitar::EngineConfiguration.new(
          custom_authenticator: Proc.new do
            render status: 499, json: { testing: true }
            false
          end
        )
      end

      context 'when authentication fails' do
        it 'renders the custom response' do
          get :index, params: { format: :scim }

          expect(response).to have_http_status(499)

          parsed_body = JSON.parse(response.body)

          expect(parsed_body).to eql('testing' => true)
        end
      end
    end
  end

  context 'authentication cascade' do
    before do
      Scimitar.engine_configuration = Scimitar::EngineConfiguration.new(
        basic_authenticator:  -> (username, password) { username == 'A' && password == 'B' },
        token_authenticator:  -> (token,    options ) { token == 'A' },
        custom_authenticator: ->                      { params[:let_me_in] == 'A' },
      )
    end

    controller do
      def index
        render json: { 'message' => 'cool, cool!' }, format: :scim
      end
    end

    it 'basic first' do
      request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials('A', 'B')

      get :index, params: { format: :scim }
      expect(response).to be_ok

      request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials('A', 'Wrong')

      get :index, params: { format: :scim }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'token after basic' do
      request.env['HTTP_AUTHORIZATION'] = 'Bearer A'

      get :index, params: { format: :scim }
      expect(response).to be_ok

      request.env['HTTP_AUTHORIZATION'] = 'Bearer B'

      get :index, params: { format: :scim }
      expect(response).to have_http_status(:unauthorized)
    end

    it 'custom after basic and token' do
      request.env['HTTP_AUTHORIZATION'] = 'Bearer Wrong'

      get :index, params: { format: :scim, let_me_in: 'A' }
      expect(response).to be_ok

      get :index, params: { format: :scim, let_me_in: 'Wrong' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context 'authenticator evaluated within controller context' do

    # Define a controller with a custom instance method 'valid_token'.
    #
    controller do
      def index
        render json: { 'message' => 'cool, cool!' }, format: :scim
      end

      def valid_token
        'B'
      end
    end

    # Call the above controller method from the token authenticator Proc,
    # proving that it was executed in the controller's context.
    #
    before do
      Scimitar.engine_configuration = Scimitar::EngineConfiguration.new(
        token_authenticator: Proc.new do | token, options |
          token == self.valid_token()
        end
      )
    end

    it 'renders success when valid creds are given' do
      request.env['HTTP_AUTHORIZATION'] = 'Bearer B'

      get :index, params: { format: :scim }
      expect(response).to be_ok
      expect(JSON.parse(response.body)).to eql({ 'message' => 'cool, cool!' })
      expect(response.headers['WWW-Authenticate']).to eql('Bearer')
    end

    it 'renders failure with bad token' do
      request.env['HTTP_AUTHORIZATION'] = 'Bearer Invalid'

      get :index, params: { format: :scim }
      expect(response).not_to be_ok
    end

    it 'renders failure with blank token' do
      request.env['HTTP_AUTHORIZATION'] = 'Bearer'

      get :index, params: { format: :scim }
      expect(response).not_to be_ok
    end

    it 'renders failure with missing header' do
      get :index, params: { format: :scim }
      expect(response).not_to be_ok
    end
  end

  context 'authenticated' do
    controller do
      rescue_from StandardError, with: :handle_resource_not_found

      def index
        render json: { 'message' => 'cool, cool!' }, format: :scim
      end

      def authenticated?
        true
      end
    end

    context 'authenticate' do
      it 'renders index if authenticated' do
        get :index, params: { format: :scim }
        expect(response).to be_ok
        expect(JSON.parse(response.body)).to eql({ 'message' => 'cool, cool!' })
      end

      it 'renders not authorized response if not authenticated' do
        allow(controller()).to receive(:authenticated?) { false }
        get :index, params: { format: :scim }
        expect(response).to have_http_status(:unauthorized)
        parsed_body = JSON.parse(response.body)
        expect(parsed_body).to include('schemas' => ['urn:ietf:params:scim:api:messages:2.0:Error'])
        expect(parsed_body).to include('detail' => 'Requires authentication')
        expect(parsed_body).to include('status' => '401')
      end

      it 'renders resource not found response when resource cannot be found for the given id' do
        allow(controller()).to receive(:index).and_raise(StandardError)
        get :index, params: { id: 10, format: :scim }
        expect(response).to have_http_status(:not_found)
        parsed_body = JSON.parse(response.body)
        expect(parsed_body).to include('schemas' => ['urn:ietf:params:scim:api:messages:2.0:Error'])
        expect(parsed_body).to include('detail' => 'Resource "10" not found')
        expect(parsed_body).to include('status' => '404')
      end
    end
  end

  context 'error handling' do
    controller do
      def index
        raise 'Bang'
      end

      def authenticated?
        true
      end
    end

    it 'handles general exceptions automatically' do
      get :index, params: { format: :scim }

      expect(response).to have_http_status(:internal_server_error)
      parsed_body = JSON.parse(response.body)
      expect(parsed_body).to include('schemas' => ['urn:ietf:params:scim:api:messages:2.0:Error'])
      expect(parsed_body).to include('status' => '500')
      expect(parsed_body).to include('detail' => 'Bang')
    end

    context 'with an exception reporter' do
      around :each do | example |
        original_configuration = Scimitar.engine_configuration.exception_reporter
        Scimitar.engine_configuration.exception_reporter = Proc.new do | exception |
          @exception = exception
        end
        example.run()
      ensure
        Scimitar.engine_configuration.exception_reporter = original_configuration
      end

      context 'and "internal server error"' do
        it 'is invoked' do
          get :index, params: { format: :scim }

          expect(@exception).to be_a(RuntimeError)
          expect(@exception.message).to eql('Bang')
        end
      end

      context 'and "not found"' do
        controller do
          def index
            handle_resource_not_found(ActiveRecord::RecordNotFound.new(42))
          end
        end

        it 'is invoked' do
          get :index, params: { format: :scim }

          expect(@exception).to be_a(ActiveRecord::RecordNotFound)
          expect(@exception.message).to eql('42')
        end
      end

      context 'and bad JSON' do
        controller do
          def index
            begin
              raise 'Hello'
            rescue
              raise ActionDispatch::Http::Parameters::ParseError
            end
          end
        end

        it 'is invoked' do
          get :index, params: { format: :scim }

          expect(@exception).to be_a(ActionDispatch::Http::Parameters::ParseError)
          expect(@exception.message).to eql('Hello')
        end
      end

      context 'and a bad content type' do
        controller do
          def index; end
        end

        it 'is invoked' do
          request.headers['Content-Type'] = 'text/plain'
          get :index

          expect(@exception).to be_a(Scimitar::ErrorResponse)
          expect(@exception.message).to eql('Only application/scim+json type is accepted.')
        end
      end

      context 'and with Google SCIM calls' do
        it 'reaches the controller action if the expected agent is making the request' do
          request.headers['Content-Type'] = 'application/json'
          request.headers['User-Agent'  ] = 'Google-Auto-Provisioning'
          get :index

          expect(@exception).to be_a(RuntimeError)
          expect(@exception.message).to eql('Bang')
        end

        it 'is invoked early for unrecognised agents' do
          request.headers['Content-Type'] = 'application/json'
          get :index

          expect(@exception).to be_a(Scimitar::ErrorResponse)
          expect(@exception.message).to eql('Only application/scim+json type is accepted.')
        end
      end # "context 'and with Google SCIM calls' do"

      context 'and with a custom request sanitizer' do
        around :each do | example |
          original_configuration = Scimitar.engine_configuration.custom_request_sanitizer
          Scimitar.engine_configuration.custom_request_sanitizer = Proc.new do | request |
            case request.media_type
              when 'application/json+success'
                :success
              when 'application/json+preserve'
                :preserve
              else
                :fail
            end
          end
          example.run()
        ensure
          Scimitar.engine_configuration.custom_request_sanitizer = original_configuration
        end

        context 'returning "success"' do
          it 'reaches the controller action with cleaned up request data' do
            request.headers['Content-Type'] = 'application/json+success'
            get :index

            expect(@exception).to be_a(RuntimeError)
            expect(@exception.message).to eql('Bang')

            expect(request.format == :scim).to eql(true)
            expect(request.headers['CONTENT_TYPE']).to eql('application/scim+json')
          end
        end # "context 'returning "success"' do"

        context 'returning "preserve"' do
          it 'reaches the controller action with unmodified request data' do
            request.headers['Content-Type'] = 'application/json+preserve'
            get :index

            expect(@exception).to be_a(RuntimeError)
            expect(@exception.message).to eql('Bang')

            expect(request.format == :html).to eql(true)
            expect(request.headers['CONTENT_TYPE']).to eql('application/json+preserve')
          end
        end # "context 'returning "keep"' do"

        context 'returning "fail"' do
          it 'is invoked' do
            request.headers['Content-Type'] = 'application/json+fail'
            get :index

            expect(@exception).to be_a(Scimitar::ErrorResponse)
            expect(@exception.message).to eql('Only application/scim+json type is accepted.')
          end
        end # "context 'returning "fail"' do"
      end # "context 'and with a custom request sanitizer' do"
    end # "context 'exception reporter' do"
  end # "context 'error handling' do"
end
