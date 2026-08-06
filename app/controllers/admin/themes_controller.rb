class Admin::ThemesController < ApplicationController
  layout 'adminpanel'
  before_action -> { require_admin_area(:theme) }

  def edit
    @general_setting = GeneralSetting.first_or_initialize
  end

  def update
    @general_setting = GeneralSetting.first_or_initialize

    if @general_setting.update(theme_params)
      Activity.log(current_user, "Updated theme settings")
      redirect_to edit_admin_theme_path, notice: 'Theme updated successfully.'
    else
      flash.now[:alert] = "Theme could not be updated: #{@general_setting.errors.full_messages.join(', ')}"
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def theme_params
    params.require(:general_setting).permit(
      :theme_primary,
      :theme_primary_hover,
      :theme_on_primary,
      :theme_bg,
      :theme_surface,
      :theme_surface_alt,
      :theme_border,
      :theme_text,
      :theme_text_muted
    )
  end
end
