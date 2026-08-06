class TenantAssetsController < ApplicationController
  def index
    business = business_for_assets
    return render json: { assets: [] }, status: :not_found if business.nil?

    category_filter = normalize_category(params[:category]) if params[:category].present?
    attachments = business.assets_attachments.includes(:blob).order(created_at: :desc)

    assets = []
    categories = Set.new

    attachments.each do |attachment|
      blob = attachment.blob
      category = asset_category(blob)
      next if category_filter.present? && category != category_filter

      categories << category
      assets << {
        id: attachment.id,
        filename: blob.filename.to_s,
        title: asset_title(blob),
        category: category,
        content_type: blob.content_type,
        byte_size: blob.byte_size,
        created_at: attachment.created_at,
        url: media_asset_path(key: blob.key)
      }
    end

    render json: { assets: assets, categories: categories.to_a.sort }
  end

  private

  # Only expose assets for the current tenant host. Do not allow enumeration by
  # arbitrary business IDs from the main platform domain.
  def business_for_assets
    return current_business if current_business.present?

    tenant_id = params[:tenant_id].presence
    return nil if tenant_id.blank?
    return nil unless user_signed_in?

    business = Business.find_by(id: tenant_id)
    return nil if business.nil?

    return business if current_user.full_admin?
    return business if current_user.business_id == business.id

    nil
  end

  def asset_title(blob)
    data = blob.metadata.fetch("xbolt", {})
    title = data.is_a?(Hash) ? data["title"].to_s.strip : ""
    title.presence || blob.filename.base
  end

  def asset_category(blob)
    data = blob.metadata.fetch("xbolt", {})
    category = data.is_a?(Hash) ? data["category"].to_s.strip : ""
    normalize_category(category)
  end

  def normalize_category(value)
    slug = value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
    slug.presence || "general"
  end
end
