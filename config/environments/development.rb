require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Load environment variables from .env file early so config values can use them.
  begin
    require 'dotenv'
    Dotenv.load if File.exist?('.env')
  rescue LoadError
    # dotenv-rails not available, continue without it
  end

  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing
  config.server_timing = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{2.days.to_i}"
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Force S3 for development uploads.
  config.active_storage.service = :amazon



  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Sprockets stores each cache entry by renaming a temp file over the target,
  # which Windows refuses while any other handle holds that target open (a
  # concurrent Puma thread, or real-time antivirus), surfacing as EACCES mid
  # request. Elsewhere the on-disk cache is kept for faster cold boots.
  if Gem.win_platform?
    config.assets.configure do |env|
      env.cache = Sprockets::Cache::MemoryStore.new(10_000)
    end
  end

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  # Set default_url_options for development
  Rails.application.routes.default_url_options[:host] = 'localhost:3001'

  # Clear hosts to allow all hosts
  config.hosts.clear

  config.action_cable.url = "ws://localhost:3001/cable"
  config.action_cable.allowed_request_origins = ['http://localhost:3001']

  # Gmail SMTP Configuration
  gmail_username = ENV['GMAIL_USERNAME'] || Rails.application.credentials.gmail_username
  gmail_password = ENV['GMAIL_PASSWORD'] || Rails.application.credentials.gmail_password
  
  if gmail_username.present? && gmail_password.present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address:              'smtp.gmail.com',
      port:                 587,
      domain:               'gmail.com',
      user_name:            gmail_username,
      password:             gmail_password,
      authentication:       'plain',
      enable_starttls_auto: true,
      openssl_verify_mode:  'none'
    }
    
    # ActionMailer configuration
    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.perform_deliveries = true
    config.action_mailer.default_url_options = { host: 'localhost:3001' }
    
    Rails.logger&.info "Gmail SMTP configured successfully"
  else
    # Use File delivery for development when Gmail credentials are not set
    # This saves emails as files in your project instead of sending them
    config.action_mailer.delivery_method = :file
    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = false
    config.action_mailer.default_url_options = { host: 'localhost:3001' }
    
    # File delivery settings
    config.action_mailer.file_settings = { location: Rails.root.join('tmp/mails') }
    
    # Only log warnings if logger is available (not during migrations)
    Rails.logger&.info "Using File delivery for email in development."
    Rails.logger&.info "Emails will be saved to tmp/mails folder."
    Rails.logger&.info "Set GMAIL_USERNAME and GMAIL_PASSWORD environment variables to enable actual email sending."
  end
end
