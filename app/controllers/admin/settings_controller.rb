class Admin::SettingsController < ApplicationController
  layout 'adminpanel'
  before_action -> { require_admin_area(:settings) }

  SETTINGS_TABS = %w[general contact social branding team faq].freeze

  def index
    @general_setting = GeneralSetting.first_or_initialize
    @active_tab = sanitize_tab(params[:tab])
  end

  def update
    @general_setting = GeneralSetting.first_or_initialize
    @active_tab = sanitize_tab(params[:tab])

    if @general_setting.update(general_setting_params)
      Activity.log(current_user, "Updated system settings")
      redirect_to admin_settings_path(tab: @active_tab), notice: "Settings updated successfully!"
    else
      flash.now[:alert] = "Settings could not be updated: #{@general_setting.errors.full_messages.join(', ')}"
      render :index, status: :unprocessable_entity
    end
  end

  private

  def sanitize_tab(value)
    tab = value.to_s.strip.downcase
    SETTINGS_TABS.include?(tab) ? tab : "general"
  end

  def general_setting_params
    params.require(:general_setting).permit(
      :application_name, :maintenance_mode, :phone_number, :contact_email, :website_url,
      :logo_url, :favicon_url,
      :linkedin_url, :facebook_url, :instagram_url, :tiktok_url, :google_reviews_url,
      :team_members_data, :faq_items_data
    )
  end
end
