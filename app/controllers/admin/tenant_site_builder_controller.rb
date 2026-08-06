require 'set'

class Admin::TenantSiteBuilderController < ApplicationController
  layout 'adminpanel'

  before_action :require_login
  before_action :require_business_user
  before_action :set_business
  before_action :ensure_default_pages, only: [:index, :publish]
  before_action :set_page, only: [:edit, :update, :destroy, :preview]

  def index
    @general_setting = GeneralSetting.first_or_initialize
    @pages = @business.tenant_site_pages.ordered
    @page = page_for_visual_editor(@pages)
    @sections_json = JSON.generate(@page.sections.presence || TenantSitePage::DEFAULT_SECTIONS)
    @static_editor = TenantStaticSiteEditor.new(business: @business)
    @static_pages = @static_editor.pages
    @static_path = params[:path].presence || @static_pages.first&.dig(:path) || '/'
    @static_deployed = @static_editor.deployed?
  end

  def new
    @general_setting = GeneralSetting.first_or_initialize
    @page = @business.tenant_site_pages.new(
      title: 'New Page',
      slug: next_available_slug,
      position: next_position,
      sections: TenantSitePage::DEFAULT_SECTIONS.deep_dup
    )
    load_editor_assets
    render :edit
  end

  def create
    @page = @business.tenant_site_pages.new(page_attributes)

    if @page.save
      redirect_to edit_admin_website_page_path(@page), notice: 'Website page created.'
    else
      @general_setting = GeneralSetting.first_or_initialize
      load_editor_assets
      render :edit, status: :unprocessable_entity
    end
  end

  def edit
    redirect_to admin_website_path(page_id: @page.id)
  end

  def update
    if @page.update(page_attributes)
      respond_to do |format|
        format.json { render json: { ok: true, page_id: @page.id, sections: @page.sections, updated_at: @page.updated_at } }
        format.html { redirect_to admin_website_path(page_id: @page.id), notice: 'Website page saved.' }
      end
    else
      respond_to do |format|
        format.json { render json: { ok: false, errors: @page.errors.full_messages }, status: :unprocessable_entity }
        format.html do
          @general_setting = GeneralSetting.first_or_initialize
          @pages = @business.tenant_site_pages.ordered
          @sections_json = JSON.generate(@page.sections.presence || [])
          render :index, status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    if @business.tenant_site_pages.count <= 1
      redirect_to admin_website_path, alert: 'Keep at least one website page.'
      return
    end

    @page.destroy!
    redirect_to admin_website_path, notice: 'Website page deleted.'
  end

  def preview
    @general_setting = GeneralSetting.first_or_initialize
    html = TenantSitePublisher.new(
      business: @business,
      pages: @business.tenant_site_pages.ordered,
      editor: params[:editor].present?
    ).render_page(@page)
    render html: html.html_safe, layout: false
  end

  def static_preview
    html = TenantStaticSiteEditor.new(business: @business).render_editor_html(path: params[:path])
    render html: html.html_safe, layout: false
  rescue ArgumentError => e
    render plain: e.message, status: :not_found
  end

  def static_asset
    abs = TenantStaticSiteEditor.new(business: @business).serve_asset(params[:path])
    return head :not_found if abs.nil?

    send_file abs, type: Rack::Mime.mime_type(File.extname(abs.to_s), 'application/octet-stream'), disposition: 'inline'
  end

  def static_update
    editor = TenantStaticSiteEditor.new(business: @business)

    if params[:text_index].present?
      editor.update_text!(path: params[:path], text_index: params[:text_index], value: params[:value])
    elsif params[:reorder].is_a?(ActionController::Parameters)
      reorder = params.require(:reorder).permit(:container_index, :old_index, :new_index)
      editor.reorder_items!(
        path: params[:path],
        container_index: reorder[:container_index],
        old_index: reorder[:old_index],
        new_index: reorder[:new_index]
      )
    else
      raise ArgumentError, 'No valid update provided.'
    end

    render json: { ok: true }
  rescue ArgumentError => e
    render json: { ok: false, message: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("Static site editor update failed for business=#{@business&.id}: #{e.class}: #{e.message}")
    render json: { ok: false, message: 'Could not save website change.' }, status: :internal_server_error
  end

  def publish
    TenantSitePublisher.new(business: @business, pages: @business.tenant_site_pages.ordered).publish!
    @business.tenant_site_pages.update_all(published_at: Time.current, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    log_activity("Published website builder site for #{@business.name} (#{@business.subdomain})")
    respond_to do |format|
      format.json { render json: { ok: true, message: 'Website published successfully.' } }
      format.html { redirect_to admin_website_path, notice: 'Website published successfully.' }
    end
  rescue ArgumentError => e
    respond_to do |format|
      format.json { render json: { ok: false, message: e.message }, status: :unprocessable_entity }
      format.html { redirect_to admin_website_path, alert: e.message }
    end
  rescue StandardError => e
    Rails.logger.error("Tenant website publish failed for business=#{@business&.id}: #{e.class}: #{e.message}")
    respond_to do |format|
      format.json { render json: { ok: false, message: 'Website publish failed. Please try again.' }, status: :internal_server_error }
      format.html { redirect_to admin_website_path, alert: 'Website publish failed. Please try again.' }
    end
  end

  private

  def require_business_user
    return if current_user.present? && !current_user.admin?

    redirect_to admin_dashboard_path, alert: 'Only tenant accounts can edit tenant websites.'
  end

  def set_business
    @business = current_user.business
    return if @business.present?

    redirect_to admin_dashboard_path, alert: 'No business account found.'
  end

  def set_page
    @page = @business.tenant_site_pages.find(params[:id])
  end

  def page_attributes
    raw_sections = params.dig(:tenant_site_page, :sections_json).presence ||
      params.dig(:tenant_site_page, :sections).presence ||
      '[]'

    {
      title: page_params[:title].to_s.strip,
      slug: page_params[:slug].to_s.strip,
      position: page_params[:position].to_i,
      sections: sanitize_sections(raw_sections)
    }
  end

  def page_params
    params.fetch(:tenant_site_page, ActionController::Parameters.new).permit(:title, :slug, :position, :sections_json, :sections)
  end

  def sanitize_sections(raw_sections)
    parsed = raw_sections.is_a?(String) ? JSON.parse(raw_sections) : raw_sections
    parsed = [] unless parsed.is_a?(Array)

    valid_asset_keys = @business.assets_attachments.includes(:blob).map { |attachment| attachment.blob.key }.to_set

    parsed.first(30).filter_map do |section|
      next unless section.is_a?(Hash)

      type = section['type'].to_s
      next unless TenantSitePage::ALLOWED_BLOCK_TYPES.include?(type)

      sanitize_section(section, type, valid_asset_keys)
    end
  rescue JSON::ParserError
    []
  end

  def sanitize_section(section, type, valid_asset_keys)
    clean = { 'type' => type }
    %w[eyebrow heading subheading body button_text button_url image_key image_alt category].each do |key|
      clean[key] = sanitize_scalar(section[key]) if section.key?(key)
    end

    if clean['image_key'].present? && !valid_asset_keys.include?(clean['image_key'])
      clean.delete('image_key')
    end

    %w[items faqs].each do |key|
      clean[key] = sanitize_items(section[key], valid_asset_keys) if section[key].is_a?(Array)
    end

    clean
  end

  def sanitize_items(items, valid_asset_keys)
    items.first(20).filter_map do |item|
      next unless item.is_a?(Hash)

      clean = {}
      %w[title subtitle body name role quote question answer image_key image_alt].each do |key|
        clean[key] = sanitize_scalar(item[key]) if item.key?(key)
      end
      clean.delete('image_key') if clean['image_key'].present? && !valid_asset_keys.include?(clean['image_key'])
      clean.presence
    end
  end

  def sanitize_scalar(value)
    value.to_s.strip[0, 2000]
  end

  def load_editor_assets
    @asset_options = @business.assets_attachments.includes(:blob).order(created_at: :desc).map do |attachment|
      blob = attachment.blob
      metadata = blob.metadata.fetch('xbolt', {})
      title = metadata.is_a?(Hash) ? metadata['title'].to_s.strip : ''
      {
        key: blob.key,
        title: title.presence || blob.filename.base,
        filename: blob.filename.to_s,
        content_type: blob.content_type.to_s,
        url: media_asset_path(key: blob.key)
      }
    end
  end

  def ensure_default_pages
    defaults = [
      ['Home', '/', 0],
      ['About', '/about', 1],
      ['Services', '/services', 2],
      ['Contact', '/contact', 3]
    ]

    defaults.each do |title, slug, position|
      @business.tenant_site_pages.find_or_create_by!(slug: slug) do |page|
        page.title = title
        page.position = position
        page.sections = default_sections_for(slug)
      end
    end
  end

  def page_for_visual_editor(pages)
    requested = params[:page_id].presence
    return pages.find { |page| page.id.to_s == requested.to_s } if requested.present?

    pages.find(&:home?) || pages.first
  end

  def default_sections_for(slug)
    case slug
    when '/'
      TenantSitePage::DEFAULT_SECTIONS.deep_dup
    when '/contact'
      [
        { 'type' => 'hero', 'heading' => 'Contact us', 'body' => 'Tell us what you need and we will get back to you soon.' },
        { 'type' => 'contact_form', 'heading' => 'Send a message', 'body' => 'We usually respond quickly.' }
      ]
    else
      [
        { 'type' => 'hero', 'heading' => 'Welcome', 'body' => 'Update this page from your website builder.' },
        { 'type' => 'text', 'heading' => 'Page content', 'body' => 'Add sections, images, galleries, cards, FAQs, and calls to action.' }
      ]
    end
  end

  def next_position
    @business.tenant_site_pages.maximum(:position).to_i + 1
  end

  def next_available_slug
    base = '/new-page'
    return base unless @business.tenant_site_pages.exists?(slug: base)

    counter = 2
    loop do
      candidate = "#{base}-#{counter}"
      return candidate unless @business.tenant_site_pages.exists?(slug: candidate)

      counter += 1
    end
  end
end
