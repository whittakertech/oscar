require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

require "whittaker_tech/oscar"

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.1
    config.root = File.expand_path('..', __dir__)

    config.eager_load = false
    config.active_record.schema_format = :sql
  end
end
