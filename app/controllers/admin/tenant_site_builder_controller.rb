require "set"

class Admin::TenantSiteBuilderController < ApplicationController
  layout :resolve_layout

  MAX_STATIC_TEXT_BYTES = TenantStaticSiteEditor::MAX_TEXT_LENGTH
  SAFE_BUTTON_URL = %r{\A(?:/|#|mailto:|tel:|https://)}i

  before_action :require_login
  before_action :require_business_user
  before_action :set_business
  before_action :ensure_default_pages, only: [:publish, :create]
  before_action :set_page, only: [:edit, :update, :destroy, :preview]

  def index
    @general_setting = general_setting
    @static_editor = TenantStaticSiteEditor.new(business: @business)
    @static_pages = @static_editor.pages
    @static_path = params[:path].presence || @static_pages.first&.dig(:path) || "/"
    @static_deployed = @static_editor.deployed?
  end

  def new
    redirect_to admin_website_path
  end

  def create
    @page = @business.tenant_site_pages.new(page_attributes)
    @page.title = "New Page" if @page.title.blank?
    @page.slug = next_available_slug if @page.slug.blank? || @page.slug == "/"
    @page.position = next_position if @page.position.to_i <= 0 && !@page.home?
    @page.sections = TenantSitePage::DEFAULT_SECTIONS.deep_dup if @page.sections.blank?

    if @page.save
      respond_to do |format|
        format.json { render json: { ok: true, page_id: @page.id, redirect_url: admin_website_path } }
        format.html { redirect_to admin_website_path, notice: "Website page created." }
      end
    else
      respond_to do |format|
        format.json { render json: { ok: false, errors: @page.errors.full_messages }, status: :unprocessable_entity }
        format.html { redirect_to admin_website_path, alert: @page.errors.full_messages.to_sentence }
      end
    end
  end

  def edit
    redirect_to admin_website_path
  end

  def update
    if @page.update(page_attributes)
      respond_to do |format|
        format.json { render json: { ok: true, page_id: @page.id, sections: @page.sections, updated_at: @page.updated_at } }
        format.html { redirect_to admin_website_path, notice: "Website page saved." }
      end
    else
      respond_to do |format|
        format.json { render json: { ok: false, errors: @page.errors.full_messages }, status: :unprocessable_entity }
        format.html { redirect_to admin_website_path, alert: @page.errors.full_messages.to_sentence }
      end
    end
  end

  def destroy
    if @business.tenant_site_pages.count <= 1
      redirect_to admin_website_path, alert: "Keep at least one website page."
      return
    end

    @page.destroy!
    redirect_to admin_website_path, notice: "Website page deleted."
  end

  def preview
    html = TenantSitePublisher.new(
      business: @business,
      pages: @business.tenant_site_pages.ordered,
      editor: params[:editor].present?
    ).render_page(@page)
    response.set_header("Content-Security-Policy", "default-src 'self' https: data: blob:; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https:; img-src 'self' https: data: blob:; frame-ancestors 'self'")
    render html: html.html_safe, layout: false
  end

  def static_preview
    html = TenantStaticSiteEditor.new(business: @business).render_editor_html(path: params[:path])
    # Preview must load tenant CDN/CSS/font/API assets freely so live refresh keeps styling.
    response.set_header(
      "Content-Security-Policy",
      [
        "default-src 'self' https: http: data: blob:",
        "script-src 'self' 'unsafe-inline' 'unsafe-eval' https: http:",
        "style-src 'self' 'unsafe-inline' https: http:",
        "font-src 'self' https: http: data:",
        "img-src 'self' https: http: data: blob:",
        "connect-src 'self' https: http: ws: wss:",
        "media-src 'self' https: http: data: blob:",
        "frame-src 'self' https: http:",
        "frame-ancestors 'self'"
      ].join("; ")
    )
    response.set_header("Cache-Control", "private, no-store")
    render html: html.html_safe, layout: false
  rescue ArgumentError => e
    render plain: e.message, status: :not_found
  end

  def static_asset
    abs = TenantStaticSiteEditor.new(business: @business).serve_asset(params[:path])
    return head :not_found if abs.nil?

    content_type = Rack::Mime.mime_type(File.extname(abs.to_s), "application/octet-stream")
    response.set_header("Cache-Control", "private, max-age=300")
    send_file abs, type: content_type, disposition: "inline"
  end

  def static_update
    editor = TenantStaticSiteEditor.new(business: @business)
    raise ArgumentError, "No custom site is deployed." unless editor.deployed?

    result = { ok: true }

    if params[:text_index].present?
      value = params[:value].to_s
      raise ArgumentError, "Text is too long." if value.bytesize > MAX_STATIC_TEXT_BYTES

      editor.update_text!(path: params[:path], text_index: params[:text_index], value: value)
    elsif params[:reorder].is_a?(ActionController::Parameters) || params[:reorder].is_a?(Hash)
      reorder = params.require(:reorder).permit(:container_index, :old_index, :new_index)
      editor.reorder_items!(
        path: params[:path],
        container_index: reorder[:container_index],
        old_index: reorder[:old_index],
        new_index: reorder[:new_index]
      )
    elsif params[:duplicate].is_a?(ActionController::Parameters) || params[:duplicate].is_a?(Hash)
      duplicate = params.require(:duplicate).permit(:container_index, :item_index)
      result = editor.duplicate_item!(
        path: params[:path],
        container_index: duplicate[:container_index],
        item_index: duplicate[:item_index]
      ) || result
    elsif params[:delete_item].is_a?(ActionController::Parameters) || params[:delete_item].is_a?(Hash)
      delete_item = params.require(:delete_item).permit(:container_index, :item_index)
      result = editor.delete_item!(
        path: params[:path],
        container_index: delete_item[:container_index],
        item_index: delete_item[:item_index]
      ) || result
    else
      raise ArgumentError, "No valid update provided."
    end

    render json: result.is_a?(Hash) ? result.reverse_merge(ok: true) : { ok: true }
  rescue ArgumentError => e
    render json: { ok: false, message: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error("Static site editor update failed for business=#{@business&.id}: #{e.class}: #{e.message}")
    render json: { ok: false, message: "Could not save website change." }, status: :internal_server_error
  end

  def publish
    static_deployed = TenantStaticSiteEditor.new(business: @business).deployed?
    if static_deployed && !ActiveModel::Type::Boolean.new.cast(params[:confirm_overwrite])
      message = "A custom ZIP site is already deployed. Publishing will replace it (a backup is kept). Confirm to continue."
      respond_to do |format|
        format.json { render json: { ok: false, requires_confirmation: true, message: message }, status: :conflict }
        format.html { redirect_to admin_website_path, alert: message }
      end
      return
    end

    TenantSitePublisher.new(business: @business, pages: @business.tenant_site_pages.ordered).publish!
    @business.tenant_site_pages.update_all(published_at: Time.current, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    log_activity("Published website builder site for #{@business.name} (#{@business.subdomain})")
    respond_to do |format|
      format.json { render json: { ok: true, message: "Website published successfully." } }
      format.html { redirect_to admin_website_path, notice: "Website published successfully." }
    end
  rescue ArgumentError => e
    respond_to do |format|
      format.json { render json: { ok: false, message: e.message }, status: :unprocessable_entity }
      format.html { redirect_to admin_website_path, alert: e.message }
    end
  rescue StandardError => e
    Rails.logger.error("Tenant website publish failed for business=#{@business&.id}: #{e.class}: #{e.message}")
    respond_to do |format|
      format.json { render json: { ok: false, message: "Website publish failed. Please try again." }, status: :internal_server_error }
      format.html { redirect_to admin_website_path, alert: "Website publish failed. Please try again." }
    end
  end

  private

  def resolve_layout
    action_name == "index" ? "website_editor" : "adminpanel"
  end

  def require_business_user
    return if current_user.present? && !current_user.staff_admin?

    redirect_to admin_dashboard_path, alert: "Only tenant accounts can edit tenant websites."
  end

  def set_business
    @business = current_user.business
    return if @business.present?

    redirect_to admin_dashboard_path, alert: "No business account found."
  end

  def set_page
    @page = @business.tenant_site_pages.find(params[:id])
  end

  def page_attributes
    raw_sections = params.dig(:tenant_site_page, :sections_json).presence ||
      params.dig(:tenant_site_page, :sections).presence ||
      "[]"

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

      type = section["type"].to_s
      next unless TenantSitePage::ALLOWED_BLOCK_TYPES.include?(type)

      sanitize_section(section, type, valid_asset_keys)
    end
  rescue JSON::ParserError
    []
  end

  def sanitize_section(section, type, valid_asset_keys)
    clean = { "type" => type }
    %w[eyebrow heading subheading body button_text button_url image_key image_alt category].each do |key|
      clean[key] = sanitize_scalar(section[key]) if section.key?(key)
    end

    if clean["button_url"].present? && !clean["button_url"].match?(SAFE_BUTTON_URL)
      clean.delete("button_url")
    end

    if clean["image_key"].present? && !valid_asset_keys.include?(clean["image_key"])
      clean.delete("image_key")
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
      clean.delete("image_key") if clean["image_key"].present? && !valid_asset_keys.include?(clean["image_key"])
      clean.presence
    end
  end

  def sanitize_scalar(value)
    value.to_s.strip[0, 2000]
  end

  def load_editor_assets
    @asset_options = @business.assets_attachments.includes(:blob).order(created_at: :desc).map do |attachment|
      blob = attachment.blob
      metadata = blob.metadata.fetch("xbolt", {})
      title = metadata.is_a?(Hash) ? metadata["title"].to_s.strip : ""
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
      ["Home", "/", 0],
      ["About", "/about", 1],
      ["Services", "/services", 2],
      ["Contact", "/contact", 3]
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
    when "/"
      TenantSitePage::DEFAULT_SECTIONS.deep_dup
    when "/contact"
      [
        { "type" => "hero", "heading" => "Contact us", "body" => "Tell us what you need and we will get back to you soon." },
        { "type" => "contact_form", "heading" => "Send a message", "body" => "We usually respond quickly." }
      ]
    else
      [
        { "type" => "hero", "heading" => "Welcome", "body" => "Update this page from your website builder." },
        { "type" => "text", "heading" => "Page content", "body" => "Add sections, images, galleries, cards, FAQs, and calls to action." }
      ]
    end
  end

  def next_position
    @business.tenant_site_pages.maximum(:position).to_i + 1
  end

  def next_available_slug
    base = "/new-page"
    return base unless @business.tenant_site_pages.exists?(slug: base)

    counter = 2
    loop do
      candidate = "#{base}-#{counter}"
      return candidate unless @business.tenant_site_pages.exists?(slug: candidate)

      counter += 1
    end
  end
end
