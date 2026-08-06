class Admin::UploadsController < ApplicationController
  before_action :require_login
  before_action :require_full_admin

  def create
    url = ImageUploadService.upload(params[:file])
    render json: { url: url }, status: :ok
  rescue ImageUploadService::ValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ImageUploadService::ConfigurationError => e
    Rails.logger.error("Image upload misconfigured: #{e.message}")
    render json: { error: "Upload is not configured" }, status: :service_unavailable
  rescue ImageUploadService::Error
    render json: { error: "Upload failed" }, status: :bad_gateway
  end
end
