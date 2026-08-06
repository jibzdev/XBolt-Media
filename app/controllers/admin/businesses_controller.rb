class Admin::BusinessesController < ApplicationController
  layout 'adminpanel'
  before_action :require_full_admin
  before_action :set_business, only: [:show, :edit, :update, :verify_custom_domain, :install_sitemap, :install_watermark, :deploy_site, :delete_site, :download_site_zip, :create_business_login, :reset_business_password, :destroy]

  def index
    @general_setting = GeneralSetting.first_or_initialize

    @q = params[:q].to_s.strip
    scope = Business.order(created_at: :desc)
    scope = scope.where("name ILIKE :q OR subdomain ILIKE :q OR custom_domain ILIKE :q", q: "%#{@q}%") if @q.present?
    @businesses = scope.page(params[:page]).per(12)

    @total_count = Business.count
    @active_count = Business.where(active: true).count
    @with_domain_count = Business.where.not(custom_domain: [nil, '']).count
    @recent_count = Business.where('created_at >= ?', 30.days.ago).count
  end

  def new
    @general_setting = GeneralSetting.first_or_initialize
    @business = Business.new
  end

  def create
    @general_setting = GeneralSetting.first_or_initialize
    @business = Business.new(business_params)

    if @business.save
      # Create an associated business account automatically (non-admin).
      begin
        generated_password = SecureRandom.base58(16)
        user = User.create!(
          username: next_business_username(@business),
          password: generated_password,
          password_confirmation: generated_password,
          admin: false,
          status: 'verified',
          business: @business
        )

        session[:new_business_account] = {
          'business_id' => @business.id,
          'user_id' => user.id,
          'username' => user.username,
          'password' => generated_password,
          'login_url' => login_url
        }
      rescue StandardError => e
        Rails.logger.error("Failed to create business user for business=#{@business.id}: #{e.class}: #{e.message}")
      end

      log_activity("Created business #{@business.name} (#{@business.subdomain})")
      redirect_to admin_business_path(@business), notice: 'Business created successfully!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @general_setting = GeneralSetting.first_or_initialize
    scope = PageView.where(business: @business)
    @page_views_24h = scope.last_24_hours.count
    @page_views_7d = scope.last_7_days.count
    @page_views_30d = scope.last_30_days.count
    @unique_visitors_7d = scope.last_7_days.unique_visitors

    @business_user = @business.users.order(created_at: :asc).first
    creds = session[:new_business_account]
    if creds.is_a?(Hash) && creds['business_id'].to_i == @business.id
      @new_business_account = creds
      session.delete(:new_business_account)
    end

    reset = session[:business_user_password_reset]
    if reset.is_a?(Hash) && reset['business_id'].to_i == @business.id
      @business_user_password_reset = reset
      session.delete(:business_user_password_reset)
    end

    @sitemap_path = Rails.root.join('public', 'tenant_sites', @business.subdomain.to_s, 'sitemap.xml')

    watermark = TenantWatermarkInstaller.new(business: @business)
    @site_deployed = watermark.deployed?
    @watermark_installed = watermark.installed?
  end

  def edit
    @general_setting = GeneralSetting.first_or_initialize
  end

  def update
    attrs = business_params

    if @business.update(attrs)
      log_activity("Updated business #{@business.name} (#{@business.subdomain})")
      if attrs.key?(:custom_domain) && @business.custom_domain.present? && @business.custom_domain_status != 'active'
        result = @business.verify_custom_domain!
        if result[:ok]
          redirect_to admin_business_path(@business), notice: 'Business updated and custom domain verified.'
        else
          redirect_to admin_business_path(@business), alert: "Business updated, but TXT verification failed: #{result[:reason]}"
        end
      else
        redirect_to admin_business_path(@business), notice: 'Business updated successfully!'
      end
    else
      @general_setting = GeneralSetting.first_or_initialize
      render :edit, status: :unprocessable_entity
    end
  end

  def verify_custom_domain
    result = @business.verify_custom_domain!
    log_activity("Verified custom domain for #{@business.name} (#{@business.custom_domain})") if result[:ok]

    if result[:ok]
      redirect_to admin_business_path(@business), notice: 'Custom domain verified. This tenant can now use that domain.'
    else
      found = result.dig(:result, :txt_records).presence || ['none']
      redirect_to admin_business_path(@business), alert: "TXT verification failed: #{result[:reason]}. Found: #{found.join(', ')}"
    end
  rescue ArgumentError => e
    redirect_to admin_business_path(@business), alert: e.message
  rescue StandardError => e
    Rails.logger.error("Domain verification failed for business=#{@business.id}: #{e.class}: #{e.message}")
    redirect_to admin_business_path(@business), alert: 'Domain verification failed. Please try again.'
  end

  def install_sitemap
    TenantSitemapInstaller.new(business: @business).install!
    log_activity("Installed sitemap for #{@business.name} (#{@business.subdomain})")
    redirect_to admin_business_path(@business), notice: 'Sitemap installed/updated successfully.'
  rescue StandardError => e
    Rails.logger.error("Sitemap install failed for business=#{@business.id}: #{e.class}: #{e.message}")
    redirect_to admin_business_path(@business), alert: 'Sitemap install failed. Please try again.'
  end

  def install_watermark
    result = TenantWatermarkInstaller.new(business: @business).install!
    log_activity("Installed XBolt watermark for #{@business.name} (#{@business.subdomain})")
    redirect_to admin_business_path(@business),
      notice: "Watermark installed on #{helpers.pluralize(result[:pages_injected], 'page')} (#{result[:pages_total]} total)."
  rescue ArgumentError => e
    redirect_to admin_business_path(@business), alert: e.message
  rescue StandardError => e
    Rails.logger.error("Watermark install failed for business=#{@business.id}: #{e.class}: #{e.message}")
    redirect_to admin_business_path(@business), alert: 'Watermark install failed. Please try again.'
  end

  def deploy_site
    uploaded = params[:site_zip]
    warnings = TenantSiteDeployer.new(business: @business, uploaded_zip: uploaded).deploy!
    log_activity("Deployed site ZIP for #{@business.name} (#{@business.subdomain})")
    if warnings.any?
      redirect_to admin_business_path(@business), notice: "Site deployed. Warnings: missing referenced assets: #{warnings.join(', ')}"
    else
      redirect_to admin_business_path(@business), notice: 'Site deployed successfully.'
    end
  rescue ArgumentError => e
    redirect_to admin_business_path(@business), alert: e.message
  rescue StandardError => e
    Rails.logger.error("Site deploy failed for business=#{@business.id}: #{e.class}: #{e.message}")
    redirect_to admin_business_path(@business), alert: 'Site deploy failed. Please try again.'
  end

  def delete_site
    TenantSiteDestroyer.new(business: @business).destroy!
    log_activity("Deleted deployed site for #{@business.name} (#{@business.subdomain})")
    redirect_to admin_business_path(@business), notice: 'Website deleted. The tenant will now show “Under construction”.'
  rescue ArgumentError => e
    redirect_to admin_business_path(@business), alert: e.message
  rescue StandardError => e
    Rails.logger.error("Site delete failed for business=#{@business.id}: #{e.class}: #{e.message}")
    redirect_to admin_business_path(@business), alert: 'Website delete failed. Please try again.'
  end

  def download_site_zip
    export_dir = Rails.root.join('tmp', 'tenant_site_exports')
    export_path = export_dir.join("#{@business.subdomain}-current.zip")

    TenantSiteExporter.new(business: @business).export_to!(export_path)

    filename = "#{@business.subdomain}-site-#{Time.current.utc.strftime('%Y%m%d-%H%M%S')}.zip"
    send_file export_path, type: 'application/zip', disposition: 'attachment', filename: filename
  rescue ArgumentError => e
    redirect_to admin_business_path(@business), alert: e.message
  rescue StandardError => e
    Rails.logger.error("Site export failed for business=#{@business.id}: #{e.class}: #{e.message}")
    redirect_to admin_business_path(@business), alert: 'Could not export site ZIP. Please try again.'
  end

  def reset_business_password
    user = @business.users.order(created_at: :asc).first
    return redirect_to admin_business_path(@business), alert: 'No business user found.' if user.nil?

    password = SecureRandom.base58(16)
    user.update!(password: password, password_confirmation: password)
    log_activity("Reset business user password for #{@business.name} (#{@business.subdomain})")

    session[:business_user_password_reset] = {
      'business_id' => @business.id,
      'user_id' => user.id,
      'username' => user.username,
      'password' => password,
      'login_url' => login_url
    }

    redirect_to admin_business_path(@business), notice: 'Business user password reset successfully.'
  rescue StandardError => e
    Rails.logger.error("Business user password reset failed for business=#{@business.id}: #{e.class}: #{e.message}")
    redirect_to admin_business_path(@business), alert: 'Password reset failed. Please try again.'
  end

  def create_business_login
    existing = @business.users.order(created_at: :asc).first
    if existing.present?
      redirect_to admin_business_path(@business), alert: 'This business already has a login. Use reset password instead.'
      return
    end

    password = SecureRandom.base58(16)
    user = User.create!(
      username: next_business_username(@business),
      password: password,
      password_confirmation: password,
      admin: false,
      admin_role: nil,
      status: 'verified',
      business: @business
    )

    log_activity("Created replacement business login for #{@business.name} (#{@business.subdomain})")
    session[:new_business_account] = {
      'business_id' => @business.id,
      'user_id' => user.id,
      'username' => user.username,
      'password' => password,
      'login_url' => login_url
    }

    redirect_to admin_business_path(@business), notice: 'Business login created successfully.'
  rescue StandardError => e
    Rails.logger.error("Business login create failed for business=#{@business.id}: #{e.class}: #{e.message}")
    redirect_to admin_business_path(@business), alert: 'Business login creation failed. Please try again.'
  end

  def destroy
    # Best-effort cleanup of tenant static site + backups
    begin
      site_root = Rails.root.join('public', 'tenant_sites', @business.subdomain.to_s)
      backups_root = Rails.root.join('public', 'tenant_sites_backups', @business.subdomain.to_s)
      FileUtils.rm_rf(site_root) if Dir.exist?(site_root)
      FileUtils.rm_rf(backups_root) if Dir.exist?(backups_root)
    rescue StandardError
      nil
    end

    name = @business.name
    sub = @business.subdomain
    @business.destroy!
    log_activity("Deleted business #{name} (#{sub})")
    redirect_to admin_businesses_path, notice: 'Business deleted.'
  rescue StandardError => e
    Rails.logger.error("Business delete failed for business=#{@business&.id}: #{e.class}: #{e.message}")
    redirect_to admin_business_path(@business), alert: 'Business delete failed. Please try again.'
  end

  private

  def set_business
    @business = Business.find(params[:id])
  end

  def business_params
    attrs = params.require(:business).permit(
      :name,
      :subdomain,
      :custom_domain,
      :description,
      :image_url,
      :active,
      :tenant_contact_sender_email,
      :tenant_contact_sender_password,
      :tenant_contact_recipient_email
    )

    # Keep existing app password if left blank in edit forms.
    attrs.delete(:tenant_contact_sender_password) if attrs[:tenant_contact_sender_password].blank?
    attrs
  end

  def next_business_username(business)
    base = business.subdomain.to_s.presence || business.name.to_s.parameterize
    base = 'tenant' if base.blank?
    username = base
    counter = 1

    while User.exists?(username: username)
      username = "#{base}#{counter}"
      counter += 1
    end

    username
  end
end

