# No public cross-origin API is exposed today. Keep CORS disabled by default.
# When a payment/webhook or public API is added, restrict origins explicitly —
# never use origins '*' with credentialed requests.
#
# Example for a future JSON API owned by this app:
# Rails.application.config.middleware.insert_before 0, Rack::Cors do
#   allow do
#     origins "https://xboltmedia.com"
#     resource "/api/*",
#       headers: :any,
#       methods: %i[get post put patch delete options head]
#   end
# end
