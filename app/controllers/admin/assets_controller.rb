class Admin::AssetsController < ApplicationController
  layout 'adminpanel'
  before_action :require_login
  before_action :require_business_user
  before_action :set_business

  def index
    @general_setting = GeneralSetting.first_or_initialize
    @assets = @business.assets_attachments.includes(:blob).order(created_at: :desc)
  end

  def create
    files = Array(params.dig(:business, :assets)).compact_blank
    if files.blank?
      redirect_to admin_assets_path, alert: 'Select at least one image or video to upload.'
      return
    end

    attachables = files.map { |file| build_tenant_attachable(file, upload_category_param) }
    @business.assets.attach(attachables)
    redirect_to admin_assets_path, notice: "Uploaded #{files.size} asset#{'s' if files.size != 1}."
  end

  def update
    attachment = @business.assets_attachments.find_by(id: params[:id])
    unless attachment
      redirect_to admin_assets_path, alert: 'Asset not found.'
      return
    end

    blob = attachment.blob
    metadata = blob.metadata.is_a?(Hash) ? blob.metadata.deep_dup : {}
    xbolt_data = metadata.fetch('xbolt', {}).is_a?(Hash) ? metadata['xbolt'].deep_dup : {}

    title = asset_update_params[:title].to_s.strip
    category = normalize_category(asset_update_params[:category])
    xbolt_data['title'] = title.presence || blob.filename.base
    xbolt_data['category'] = category

    metadata['xbolt'] = xbolt_data
    blob.update!(metadata: metadata)

    redirect_to admin_assets_path, notice: 'Asset details updated.'
  end

  def destroy
    attachment = @business.assets_attachments.find_by(id: params[:id])
    unless attachment
      redirect_to admin_assets_path, alert: 'Asset not found.'
      return
    end

    attachment.purge_later
    redirect_to admin_assets_path, notice: 'Asset deleted.'
  end

  private

  def set_business
    @business = current_user.business
    return if @business.present?

    redirect_to admin_dashboard_path, alert: 'No business account found.'
  end

  def require_business_user
    return if current_user.present? && !current_user.admin?

    redirect_to admin_dashboard_path, alert: 'Only tenant accounts can access assets.'
  end

  def build_tenant_attachable(file, upload_category)
    ext = File.extname(file.original_filename.to_s).downcase
    ext = '.bin' if ext.blank?
    title = File.basename(file.original_filename.to_s, '.*').to_s.strip
    {
      io: file.tempfile,
      filename: file.original_filename.to_s,
      content_type: file.content_type,
      metadata: {
        xbolt: {
          title: title.presence || 'Untitled',
          category: upload_category
        }
      },
      key: "tenants/#{@business.id}/assets/#{Time.current.utc.strftime('%Y/%m')}/#{SecureRandom.uuid}#{ext}"
    }
  end

  def asset_update_params
    params.fetch(:asset, {}).permit(:title, :category)
  end

  def upload_category_param
    normalize_category(params.dig(:business, :upload_category))
  end

  def normalize_category(value)
    slug = value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
    slug.presence || 'general'
  end
end
