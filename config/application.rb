require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MedApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.assets.paths << Rails.root.join("public")

    # Load lib/ (e.g. TenantConstraint)
    config.autoload_paths << Rails.root.join("lib")
    config.eager_load_paths << Rails.root.join("lib")

    # Render themed error pages via Rails (instead of static public/*.html)
    # so they inherit the admin theme CSS variables.
    config.exceptions_app = self.routes

    config.action_dispatch.cookies_same_site_protection = :lax

    # Active Record encryption (tenant SMTP passwords, etc.).
    # Values are finalized in config/initializers/active_record_encryption.rb.
    # Keep support for existing plaintext until records are re-saved.
    config.active_record.encryption.support_unencrypted_data = true
  end
end
