class Admin::SettingsController < ApplicationController
  layout "adminpanel"
  before_action -> { require_admin_area(:settings) }

  SETTINGS_TABS = %w[general contact social branding team faq].freeze

  TAB_PARAMS = {
    "general" => %i[application_name maintenance_mode],
    "contact" => %i[phone_number contact_email website_url],
    "social" => %i[linkedin_url facebook_url instagram_url tiktok_url google_reviews_url],
    "branding" => %i[logo_url favicon_url],
    "team" => %i[team_members_data],
    "faq" => %i[faq_items_data]
  }.freeze

  def index
    @general_setting = GeneralSetting.first_or_initialize
    @active_tab = sanitize_tab(params[:tab])
  end

  def update
    @general_setting = GeneralSetting.first_or_initialize
    @active_tab = sanitize_tab(params[:tab])

    attrs = general_setting_params
    if attrs.empty?
      redirect_to admin_settings_path(tab: @active_tab), alert: "Nothing to save on this tab."
      return
    end

    if @general_setting.update(attrs)
      Activity.log(current_user, "Updated system settings (#{@active_tab})")
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
    allowed = TAB_PARAMS.fetch(@active_tab, TAB_PARAMS["general"])
    raw = params.fetch(:general_setting, ActionController::Parameters.new)
    raw.permit(*allowed)
  end
end
