class ApplicationController < ActionController::Base
  MODERATOR_ADMIN_AREAS = %i[
    overview
    services
    reviews
    messages
    users
    settings
    theme
    demo_website
  ].freeze

  LAST_ACTIVE_TOUCH_INTERVAL = 5.minutes

  helper_method :current_user, :user_signed_in?, :admin?
  helper_method :moderator?, :full_admin?, :super_admin?, :can_access_admin_area?
  helper_method :impersonating?, :current_impersonator
  helper_method :current_business, :general_setting

  prepend_before_action :block_banned_ip
  before_action :update_last_active
  before_action :check_maintenance_mode
  before_action :track_page_view

  private

  def block_banned_ip
    ip = BannedIp.normalize_ip(RequestIp.client_ip(request))
    banned = BannedIp.find_by(ip_address: ip)
    return unless banned

    banned.update_column(:last_seen_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
    reset_session

    if request.format.html?
      render template: "errors/forbidden", layout: "public", status: :forbidden
    else
      head :forbidden
    end
  rescue StandardError => e
    Rails.logger.error("Banned IP check failed: #{e.class}: #{e.message}")
    # Fail closed in production so ban enforcement cannot be bypassed by DB errors.
    return head :service_unavailable if Rails.env.production?

    nil
  end

  def current_business
    return @current_business if defined?(@current_business)

    host = request.host.to_s.downcase.delete_suffix(".")
    business = nil

    if host.present?
      custom_domain_candidates = [host]
      if host.start_with?("www.")
        bare_host = host.delete_prefix("www.")
        custom_domain_candidates << bare_host if bare_host.present?
      else
        custom_domain_candidates << "www.#{host}"
      end
      business = Business.where(custom_domain_status: "active")
                         .where("lower(custom_domain) IN (?)", custom_domain_candidates.uniq)
                         .first
    end

    if business.nil? && eligible_for_subdomain_lookup?(host)
      sub = extract_subdomain_for_request(host)
      business = Business.find_by(subdomain: sub) if sub.present? && sub != "www"
    end

    @current_business = business
  rescue StandardError
    @current_business = nil
  end

  def extract_subdomain_for_request(host)
    sub = request.subdomains.first.to_s.downcase
    return sub if sub.present?

    if host.end_with?(".localhost") || host.end_with?(".lvh.me")
      return host.split(".").first.to_s.downcase
    end

    nil
  end

  def eligible_for_subdomain_lookup?(host)
    return true if host.end_with?(".localhost") || host.end_with?(".lvh.me")
    return false if host.blank?

    platform_host = platform_host_for_tenants
    return false if platform_host.blank?

    host == platform_host || host.end_with?(".#{platform_host}")
  end

  def platform_host_for_tenants
    configured = GeneralSetting.first_or_initialize.website_url.presence
    fallback = Rails.application.routes.default_url_options[:host]
    candidate = configured.presence || fallback

    candidate.to_s
             .sub(%r{\Ahttps?://}i, "")
             .split("/")
             .first
             .to_s
             .split(":")
             .first
             .downcase
             .delete_suffix(".")
  rescue StandardError
    nil
  end

  def track_page_view
    return unless request.get?
    return unless request.format.html?

    path = request.path.to_s
    return if path.start_with?("/dashboard")
    return if path.start_with?("/auth")
    return if path.start_with?("/rails")
    return if path.start_with?("/assets")
    return if path.start_with?("/media")

    PageView.create(
      business: current_business,
      event_name: "page_view",
      path: path,
      host: request.host.to_s,
      referrer: request.referer,
      referrer_domain: safe_referrer_domain(request.referer),
      user_agent: request.user_agent,
      device_type: detect_device_type(request.user_agent),
      browser: detect_browser(request.user_agent),
      os: detect_os(request.user_agent),
      country_code: (request.headers["CF-IPCountry"].presence || request.headers["X-Country-Code"].presence)&.to_s&.upcase,
      ip_hash: RequestIp.hash_for(RequestIp.client_ip(request)),
      occurred_at: Time.current
    )
  rescue StandardError
    nil
  end

  def safe_referrer_domain(ref)
    return nil if ref.blank?

    URI.parse(ref).host
  rescue StandardError
    nil
  end

  def detect_device_type(ua)
    s = ua.to_s
    return "Bot" if s.match?(/bot|crawler|spider|slurp|facebookexternalhit|bingpreview/i)
    return "Tablet" if s.match?(/ipad|tablet/i)
    return "Mobile" if s.match?(/mobi|iphone|android/i)
    return "Desktop" if s.present?

    nil
  end

  def detect_browser(ua)
    s = ua.to_s
    return nil if s.blank?
    return "Edge" if s.include?("Edg/")
    return "Chrome" if s.include?("Chrome/") && !s.include?("Edg/")
    return "Firefox" if s.include?("Firefox/")
    return "Safari" if s.include?("Safari/") && !s.include?("Chrome/")

    "Other"
  end

  def detect_os(ua)
    s = ua.to_s
    return nil if s.blank?
    return "iOS" if s.match?(/iphone|ipad|ipod/i)
    return "Android" if s.match?(/android/i)
    return "Windows" if s.match?(/windows/i)
    return "macOS" if s.match?(/mac os x|macintosh/i)
    return "Linux" if s.match?(/linux/i)

    "Other"
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  rescue ActiveRecord::RecordNotFound
    session[:user_id] = nil
    nil
  end

  def current_impersonator
    return nil if session[:impersonator_user_id].blank?

    @current_impersonator ||= User.find_by(id: session[:impersonator_user_id])
  end

  def impersonating?
    current_impersonator.present? && current_impersonator.super_admin? && current_impersonator.id != current_user&.id
  end

  def user_signed_in?
    current_user.present?
  end

  def admin?
    current_user&.staff_admin?
  end

  def moderator?
    current_user&.moderator?
  end

  def full_admin?
    current_user&.full_admin?
  end

  def super_admin?
    current_user&.super_admin?
  end

  def can_access_admin_area?(area)
    return false unless current_user&.staff_admin?
    return true if current_user.full_admin?

    current_user.moderator? && MODERATOR_ADMIN_AREAS.include?(area.to_sym)
  end

  def update_last_active
    return unless user_signed_in?

    last_touch = current_user.last_active_at
    return if last_touch.present? && last_touch > LAST_ACTIVE_TOUCH_INTERVAL.ago

    current_user.update_columns(last_active_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def general_setting
    @general_setting ||= GeneralSetting.first_or_initialize
  end

  def check_maintenance_mode
    if general_setting.maintenance_mode && !current_user&.staff_admin?
      redirect_to root_path, alert: "Site is currently under maintenance. Please try again later."
    end
  end

  def require_login
    unless user_signed_in?
      redirect_to login_path, notice: "You must be logged in to access this section"
    end
  end

  def require_email_verification
    if user_signed_in? && current_user.status != "verified"
      redirect_to verify_email_page_path, alert: "Please verify your email address to access the dashboard"
    end
  end

  def require_admin
    unless current_user&.staff_admin?
      redirect_to admin_dashboard_path, alert: "No access. Contact an admin to enable privileges."
    end
  end

  def require_full_admin
    unless current_user&.full_admin?
      redirect_to admin_dashboard_path, alert: "No access. This section requires admin privileges."
    end
  end

  def require_super_admin
    unless current_user&.super_admin?
      redirect_to admin_dashboard_path, alert: "No access. This section requires super admin privileges."
    end
  end

  def require_admin_area(area)
    unless can_access_admin_area?(area)
      redirect_to admin_dashboard_path, alert: "No access. Contact an admin to enable privileges."
    end
  end

  def log_activity(description, user: current_user)
    return unless user

    Activity.log(user, description)
  rescue StandardError => e
    Rails.logger.error("Failed to log activity: #{e.class}: #{e.message}")
  end

  def log_ip_activity(user: current_user)
    return unless user

    IpLog.create(
      user: user,
      ip_address: RequestIp.client_ip(request),
      login_time: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("Failed to log IP activity: #{e.class}: #{e.message}")
  end

end
