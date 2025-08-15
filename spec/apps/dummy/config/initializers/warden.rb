require 'warden'

Rails.application.config.middleware.use Warden::Manager
