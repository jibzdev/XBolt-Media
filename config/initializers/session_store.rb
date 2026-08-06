Rails.application.config.session_store :cookie_store,
  key: "_xbolt_session",
  same_site: :lax,
  httponly: true,
  secure: Rails.env.production?,
  expire_after: 14.days
