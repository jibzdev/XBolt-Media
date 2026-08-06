require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.hosts.clear
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.cache_classes = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  config.public_file_server.enabled = true

  # Ensures that a master key has been made available in either ENV["RAILS_MASTER_KEY"]
  # or in config/master.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Compress CSS using a preprocessor.
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Store uploaded files in Amazon S3 (see config/storage.yml for options).
  config.active_storage.service = :amazon

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Include generic and useful information about system operation, but avoid logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII).
  config.log_level = :info

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "MedApp_production"

  # Email functionality removed

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require "syslog/logger"
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new "app-name")

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  Rails.application.routes.default_url_options[:host] = 'xboltmedia.com'

  # Load environment variables from .env files if dotenv-rails is available
  begin
    require 'dotenv'
    # Load .env.production first, then .env as fallback
    Dotenv.load('.env.production') if File.exist?('.env.production')
    Dotenv.load('.env') if File.exist?('.env')
  rescue LoadError
    # dotenv-rails not available, continue without it
  end

  # Mailer baseline: keep delivery enabled in production.
  # Individual mailers (like tenant contact mail) can override SMTP credentials per message.
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { host: 'xboltmedia.com' }

  # Gmail SMTP Configuration
  gmail_username = ENV['GMAIL_USERNAME'] || Rails.application.credentials.gmail_username
  gmail_password = ENV['GMAIL_PASSWORD'] || Rails.application.credentials.gmail_password
  
  if gmail_username.present? && gmail_password.present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address:              'smtp.gmail.com',
      port:                 587,
      domain:               'xboltmedia.com',
      user_name:            gmail_username,
      password:             gmail_password,
      authentication:       'plain',
      enable_starttls_auto: true,
      openssl_verify_mode:  'none',
      return_response:      true,
      enable_ssl:           false
    }
    
    Rails.logger&.info "Gmail SMTP configured successfully in production"
  else
    # Keep SMTP delivery enabled so per-message tenant SMTP options still work.
    # Mailers relying on global credentials may fail until GMAIL_USERNAME/GMAIL_PASSWORD are set.
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address:              'smtp.gmail.com',
      port:                 587,
      domain:               'xboltmedia.com',
      authentication:       'plain',
      enable_starttls_auto: true
    }
    
    # Only log errors if logger is available (not during migrations)
    if defined?(Rails.logger) && Rails.logger
      Rails.logger.warn "Global Gmail SMTP credentials not found. Tenant-specific SMTP can still send."
      Rails.logger.warn "Set GMAIL_USERNAME and GMAIL_PASSWORD to enable global/default mailers."
    end
  end
end