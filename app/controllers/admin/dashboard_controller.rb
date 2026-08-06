class Admin::DashboardController < ApplicationController
  layout 'adminpanel'
  before_action :require_login
  before_action :require_super_admin, only: [:activity_live_view, :page_insights]

  def overview
    @general_setting = GeneralSetting.first_or_initialize

    unless current_user&.admin?
      @business = current_user.business
      if @business.present?
        build_business_analytics(@business)
        render :business_overview
      else
        render :no_access, status: :forbidden
      end
      return
    end

    build_admin_analytics
  end

  def activity_live_view
    @general_setting = GeneralSetting.first_or_initialize
    @recent_activities = Activity.includes(:user).order(created_at: :desc).page(params[:page]).per(20)
    @online_users = User.where('last_active_at > ?', 15.minutes.ago).count
    @total_users = User.count
    @new_users_today = User.where('created_at > ?', Date.current.beginning_of_day).count
    @activities_today = Activity.where('created_at > ?', Date.current.beginning_of_day).count
  end

  def page_insights
    @general_setting = GeneralSetting.first_or_initialize
    raw_path = params[:path].to_s
    @path = raw_path[0, 500]

    if @path.blank?
      redirect_to admin_overview_path, alert: 'Page path is required.'
      return
    end

    scope = PageView.page_hits.where(path: @path).where('occurred_at > ?', 30.days.ago)

    @total_views = scope.count
    @unique_visitors = scope.distinct.count(:ip_hash)
    @views_24h = scope.where('occurred_at > ?', 24.hours.ago).count
    @top_referrers = scope.group(:referrer_domain).order(Arel.sql('COUNT(*) DESC')).limit(10).count
    @top_hosts = scope.group(:host).order(Arel.sql('COUNT(*) DESC')).limit(10).count
    @top_countries = scope.group(:country_code).order(Arel.sql('COUNT(*) DESC')).limit(10).count
    @top_devices = scope.group(:device_type).order(Arel.sql('COUNT(*) DESC')).limit(10).count
    @recent_hits = scope.order(occurred_at: :desc).limit(100)
  end

  private

  def build_admin_analytics
    @total_businesses = Business.count
    @total_users = User.count
    @total_services = Service.count
    @active_services = Service.active.count
    @active_users = User.where('last_active_at > ?', 7.days.ago).count

    scope_all = PageView.page_hits
    event_scope = PageView.where('occurred_at > ?', 30.days.ago)

    @page_views_24h = scope_all.last_24_hours.count
    @page_views_7d = scope_all.last_7_days.count
    @page_views_30d = scope_all.last_30_days.count

    @prev_views_24h = scope_all.previous_24_hours.count
    @prev_views_7d = scope_all.previous_7_days.count

    @unique_visitors_24h = scope_all.last_24_hours.unique_visitors
    @unique_visitors_7d = scope_all.last_7_days.unique_visitors
    @unique_visitors_30d = scope_all.last_30_days.unique_visitors
    @prev_unique_24h = scope_all.previous_24_hours.unique_visitors
    @prev_unique_7d = scope_all.previous_7_days.unique_visitors
    @prev_unique_30d = scope_all.previous_30_days.unique_visitors

    @views_by_hour = scope_all.views_by_hour(hours: 24)
    @views_last_24h = @views_by_hour
    @views_last_7d = build_views_by_day(scope_all, 7)
    @views_last_30d = build_views_by_day(scope_all, 30)

    scope_7d = scope_all.last_7_days
    @views_by_day = @views_last_7d

    @top_pages = scope_7d.top_breakdown(:path, limit: 8)
    @top_referrers = scope_7d.top_breakdown(:referrer_domain, limit: 8)
    @device_breakdown = scope_7d.top_breakdown(:device_type, limit: 6)
    @browser_breakdown = scope_7d.top_breakdown(:browser, limit: 6)
    @os_breakdown = scope_7d.top_breakdown(:os, limit: 6)
    @country_breakdown = scope_7d.top_breakdown(:country_code, limit: 10)

    @phone_clicks_24h = event_scope.event('phone_click').last_24_hours.count
    @phone_clicks_7d = event_scope.event('phone_click').last_7_days.count
    @phone_clicks_30d = event_scope.event('phone_click').count
    @contact_submits_24h = ContactMessage.where('created_at > ?', 24.hours.ago).count
    @contact_submits_7d = ContactMessage.where('created_at > ?', 7.days.ago).count
    @contact_submits_30d = ContactMessage.where('created_at > ?', 30.days.ago).count

    @recent_activities = Activity.includes(:user).order(created_at: :desc).limit(8)
    @recent_activity = @recent_activities

    @top_businesses = Business.left_joins(:page_views)
      .where('page_views.occurred_at > ?', 7.days.ago)
      .where("page_views.event_name IS NULL OR page_views.event_name = 'page_view'")
      .group('businesses.id')
      .order(Arel.sql('COUNT(page_views.id) DESC'))
      .limit(5)
      .select('businesses.*, COUNT(page_views.id) AS views_count')

    # Opportunistic scheduler: ensures a security audit runs at most once per hour
    security_key = 'security_audit:last_enqueued_at'
    last_enqueued_at = Rails.cache.read(security_key)
    if last_enqueued_at.blank? || last_enqueued_at < 1.hour.ago
      SecurityAuditJob.perform_later
      Rails.cache.write(security_key, Time.current, expires_in: 2.hours)
    end
  end

  def build_business_analytics(business)
    scope = PageView.page_hits.where(business: business)
    event_scope = PageView.where(business: business).where('occurred_at > ?', 30.days.ago)

    @page_views_24h = scope.last_24_hours.count
    @page_views_7d = scope.last_7_days.count
    @page_views_30d = scope.last_30_days.count

    @prev_views_24h = scope.previous_24_hours.count
    @prev_views_7d = scope.previous_7_days.count

    @unique_visitors_24h = scope.last_24_hours.unique_visitors
    @unique_visitors_7d = scope.last_7_days.unique_visitors
    @unique_visitors_30d = scope.last_30_days.unique_visitors
    @prev_unique_24h = scope.previous_24_hours.unique_visitors
    @prev_unique_7d = scope.previous_7_days.unique_visitors
    @prev_unique_30d = scope.previous_30_days.unique_visitors

    @site_deployed = File.file?(Rails.root.join('public', 'tenant_sites', business.subdomain.to_s, 'index.html'))

    @views_by_hour = scope.views_by_hour(hours: 24)
    @views_last_24h = @views_by_hour
    @views_last_7d = build_views_by_day(scope, 7)
    @views_last_30d = build_views_by_day(scope, 30)

    scope_7d = scope.last_7_days
    @views_by_day = @views_last_7d

    @top_pages = scope_7d.top_breakdown(:path, limit: 8)
    @top_referrers = scope_7d.top_breakdown(:referrer_domain, limit: 8)
    @device_breakdown = scope_7d.top_breakdown(:device_type, limit: 6)
    @browser_breakdown = scope_7d.top_breakdown(:browser, limit: 6)
    @os_breakdown = scope_7d.top_breakdown(:os, limit: 6)
    @country_breakdown = scope_7d.top_breakdown(:country_code, limit: 10)

    @phone_clicks_24h = event_scope.event('phone_click').last_24_hours.count
    @phone_clicks_7d = event_scope.event('phone_click').last_7_days.count
    @phone_clicks_30d = event_scope.event('phone_click').count
    @contact_submits_24h = ContactMessage.where(business: business).where('created_at > ?', 24.hours.ago).count
    @contact_submits_7d = ContactMessage.where(business: business).where('created_at > ?', 7.days.ago).count
    @contact_submits_30d = ContactMessage.where(business: business).where('created_at > ?', 30.days.ago).count
  end

  def build_views_by_day(scope, days)
    grouped = scope.where('occurred_at > ?', days.days.ago).pluck(:occurred_at).group_by(&:to_date).transform_values(&:size)
    days.times { |i| grouped[i.days.ago.to_date] ||= 0 }
    grouped.sort.to_h
  end

  helper_method :status_color, :percent_change

  def status_color(status)
    case status
    when 'confirmed' then 'green'
    when 'pending' then 'yellow'
    when 'in_progress' then 'blue'
    when 'completed' then 'purple'
    when 'cancelled' then 'red'
    else 'gray'
    end
  end

  def percent_change(current, previous)
    return 0 if previous.nil? || previous.zero?
    ((current - previous).to_f / previous * 100).round(1)
  end
end
