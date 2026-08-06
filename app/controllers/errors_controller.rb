class ErrorsController < ApplicationController
  layout 'public'

  # Avoid redirect loops / analytics writes on error pages
  skip_before_action :update_last_active
  skip_before_action :check_maintenance_mode
  skip_before_action :track_page_view
  before_action :load_general_setting

  def not_found
    render status: :not_found
  end

  def unprocessable_entity
    render status: :unprocessable_entity
  end

  def internal_server_error
    render status: :internal_server_error
  end

  private

  def load_general_setting
    @general_setting = GeneralSetting.first_or_initialize
  rescue StandardError
    @general_setting = GeneralSetting.new
  end
end

