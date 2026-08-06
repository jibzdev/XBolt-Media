class AssetLinksController < ApplicationController
  def show
    blob = ActiveStorage::Blob.find_by(key: params[:key].to_s)
    return head :not_found if blob.nil?

    disposition = params[:download].to_s == '1' ? 'attachment' : 'inline'
    redirect_to rails_blob_url(
      blob,
      disposition: disposition,
      host: app_host_for_blob_links,
      protocol: app_protocol_for_blob_links
    ), allow_other_host: true
  end

  private

  def app_host_for_blob_links
    configured_host = Rails.application.routes.default_url_options[:host].to_s.strip
    return configured_host if configured_host.present?

    request.host_with_port
  end

  def app_protocol_for_blob_links
    configured_protocol = Rails.application.routes.default_url_options[:protocol].to_s.strip
    return configured_protocol.delete_suffix('://') if configured_protocol.present?

    request.ssl? ? 'https' : 'http'
  end
end
