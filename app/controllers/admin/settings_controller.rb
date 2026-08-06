class Admin::SettingsController < ApplicationController
  layout 'adminpanel'
  before_action -> { require_admin_area(:settings) }

  def index
    @general_setting = GeneralSetting.first_or_initialize
  end

  def update
    @general_setting = GeneralSetting.first_or_initialize
    
    general_success = @general_setting.update(general_setting_params)
    
    if general_success
      Activity.log(current_user, "Updated system settings")
      redirect_to admin_settings_path, notice: 'Settings updated successfully!'
    else
      flash.now[:alert] = "General settings could not be updated: #{@general_setting.errors.full_messages.join(', ')}"
      render :index
    end
  end

  private

  def general_setting_params
    params.require(:general_setting).permit(
      :application_name, :maintenance_mode, :phone_number, :contact_email, :website_url,
      :logo_url, :favicon_url,
      :linkedin_url, :facebook_url, :instagram_url, :tiktok_url, :google_reviews_url
    )
  end
end
