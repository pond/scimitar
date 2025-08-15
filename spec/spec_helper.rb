# ============================================================================
# PREAMBLE
# ============================================================================

# Get code coverage reports:
#
# https://github.com/colszowka/simplecov#getting-started
#
# "Load and launch SimpleCov at the very top of your test/test_helper.rb (or
#  spec_helper.rb [...])"
#
require 'simplecov'
SimpleCov.start 'rails'

# Rails stuff is related to the self-test applications in 'spec/apps'.
#
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../apps/dummy/config/environment', __FILE__)
abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'rspec/rails'
require 'debug'
require 'warden'
require 'warden-rspec-rails'
require 'scimitar'

# ============================================================================
# MAIN RSPEC CONFIGURATION
# ============================================================================

RSpec.configure do | config |
  config.disable_monkey_patching!
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.raise_errors_for_deprecations!

  config.include(Warden::Test::ControllerHelpers, type: :controller) # (from the warden-rspec-rails gem)

  config.color                      = true
  config.tty                        = true
  config.order                      = :random
  config.fixture_paths              = ["#{::Rails.root}/spec/fixtures"]
  config.use_transactional_fixtures = true

  Kernel.srand config.seed

  config.around :each do | example |
    original_engine_configuration = Scimitar.instance_variable_get('@engine_configuration')
    example.run()
  ensure
    Scimitar.instance_variable_set('@engine_configuration', original_engine_configuration)
  end
end

# ============================================================================
# MISCELLANEOUS UTILITIES
# ============================================================================

# Capture stdout from running a given block.
#
def spec_helper_capture_stdout( &block )
  result = ''

  begin
    old_stdout = $stdout
    $stdout = StringIO.new

    yield

    result = $stdout.string

  ensure
    $stdout = old_stdout

  end

  return result
end

# Recursively transform the keys of any given Hash or any Hashes in a given
# Array into uppercase form, retaining Symbol or String keys. Returns the
# transformed duplicate structure.
#
# Only Hashes or Hash entries within an Array are converted. Other data is left
# alone. The original input item is not modified.
#
# IMPORTANT: HashWithIndifferentAccess or similar subclasses are not supported.
#
# +item+:: Hash or Array that might contain some Hashes.
#
def spec_helper_hupcase(item)
  if item.is_a?(Hash)
    rehash = item.transform_keys(&:upcase)
    rehash.each do | key, value |
      rehash[key] = spec_helper_hupcase(value)
    end
    rehash
  elsif item.is_a?(Array)
    item.map do | array_entry |
      spec_helper_hupcase(array_entry)
    end
  else
    item
  end
end
