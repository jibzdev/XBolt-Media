class TenantAssetsController < ApplicationController
  def index
    business = business_for_assets
    return render json: { assets: [] } if business.nil?

    category_filter = normalize_category(params[:category]) if params[:category].present?
    all_assets = business.assets_attachments.includes(:blob).order(created_at: :desc)
    all_assets = all_assets.select { |attachment| asset_category(attachment.blob) == category_filter } if category_filter.present?

    assets = all_assets.map do |attachment|
      blob = attachment.blob
      {
        id: attachment.id,
        filename: blob.filename.to_s,
        title: asset_title(blob),
        category: asset_category(blob),
        content_type: blob.content_type,
        byte_size: blob.byte_size,
        created_at: attachment.created_at,
        url: media_asset_path(key: blob.key)
      }
    end

    categories = assets.map { |asset| asset[:category] }.uniq.sort
    render json: { assets: assets, categories: categories }
  end

  private

  def business_for_assets
    tenant_id = params[:tenant_id].presence
    return Business.find_by(id: tenant_id) if tenant_id.present?

    current_business
  end

  def asset_title(blob)
    data = blob.metadata.fetch('xbolt', {})
    title = data.is_a?(Hash) ? data['title'].to_s.strip : ''
    title.presence || blob.filename.base
  end

  def asset_category(blob)
    data = blob.metadata.fetch('xbolt', {})
    category = data.is_a?(Hash) ? data['category'].to_s.strip : ''
    normalize_category(category)
  end

  def normalize_category(value)
    slug = value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
    slug.presence || 'general'
  end
end
