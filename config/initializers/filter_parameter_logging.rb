# Be sure to restart your server when you modify this file.

# Configure parameters to be filtered from the log file. Use this to limit dissemination of
# sensitive information. See the ActiveSupport::ParameterFilter documentation for supported
# notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :password, :password_confirmation,
  :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn,
  :tenant_contact_sender_password, :gmail_password,
  :access_key, :secret_access_key, :authorization,
  :card, :cvv, :cvc, :pan
]
