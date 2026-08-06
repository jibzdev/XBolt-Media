# Application-wide Content Security Policy.
# Inline scripts/styles are still used by some admin forms; tighten to nonces later.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self
    policy.object_src  :none
    policy.frame_ancestors :self
    policy.form_action :self
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.media_src   :self, :https, :data, :blob
    policy.connect_src :self, :https, :wss
    policy.style_src   :self, :https, :unsafe_inline
    policy.script_src  :self, :https, :unsafe_inline
  end

  # Report-only first would be safer for brand-new policies; enforce baseline now
  # because object-src/frame-ancestors already block the highest-risk vectors.
  # config.content_security_policy_report_only = true
end
