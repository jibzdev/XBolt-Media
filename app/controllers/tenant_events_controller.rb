class TenantEventsController < ApplicationController
  skip_before_action :verify_authenticity_token

  ALLOWED_EVENTS = %w[phone_click].freeze

  def create
    business = current_business
    return head :not_found if business.nil?

    event_name = params[:event].to_s
    return head :unprocessable_entity unless ALLOWED_EVENTS.include?(event_name)

    PageView.create(
      business: business,
      event_name: event_name,
      path: sanitized_path,
      host: request.host.to_s,
      referrer: request.referer,
      referrer_domain: safe_referrer_domain(request.referer),
      user_agent: request.user_agent,
      device_type: detect_device_type(request.user_agent),
      browser: detect_browser(request.user_agent),
      os: detect_os(request.user_agent),
      country_code: (request.headers['CF-IPCountry'].presence || request.headers['X-Country-Code'].presence)&.to_s&.upcase,
      ip_hash: request.remote_ip.to_s,
      occurred_at: Time.current
    )

    head :ok
  rescue StandardError => e
    Rails.logger.error("Tenant event tracking failed: #{e.class}: #{e.message}")
    head :ok
  end

  private

  def sanitized_path
    raw = params[:path].to_s
    candidate = raw.present? ? raw : URI.parse(request.referer.to_s).path
    candidate = "/" if candidate.blank?
    candidate[0, 500]
  rescue StandardError
    "/"
  end
end
