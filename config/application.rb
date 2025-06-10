require_relative "boot"

require "rails"

# Only include the frameworks needed for API mode
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie" # optional, only if you use view rendering for emails or PDFs
require "active_storage/engine"
require "sprockets/railtie" if defined?(Sprockets) # optional: only needed if you still serve assets
require "kaminari"

Bundler.require(*Rails.groups)

module Cashly
  class Application < Rails::Application
    config.load_defaults 8.0

    # Enable API-only mode (no view rendering, assets, etc.)
    config.api_only = true

    config.autoload_paths += %W[
  #{config.root}/app/operations
  #{config.root}/app/domains
  #{config.root}/app/queries
  #{config.root}/app/presenters
  #{config.root}/app/forms
]

    # Automatically load files in lib/, excluding non-Ruby directories
    config.autoload_lib(ignore: %w[assets tasks])

    # Set time zone or localization if needed
    # config.time_zone = "Eastern Time (US & Canada)"
    # config.i18n.default_locale = :en

    # Allow CORS requests from your frontend
    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins "*" # Replace with your frontend domain in production
        resource "*", headers: :any, methods: [ :get, :post, :put, :patch, :delete, :options ]
      end
    end
  end
end
