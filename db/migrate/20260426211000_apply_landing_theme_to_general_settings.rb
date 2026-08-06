class ApplyLandingThemeToGeneralSettings < ActiveRecord::Migration[7.0]
  LANDING_THEME = {
    theme_primary: "#f59e0b",
    theme_primary_hover: "#fbbf24",
    theme_on_primary: "#09090b",
    theme_bg: "#09090b",
    theme_surface: "#111113",
    theme_surface_alt: "#0a0a0c",
    theme_border: "#27272a",
    theme_text: "#ffffff",
    theme_text_muted: "#71717a"
  }.freeze

  PREVIOUS_THEME = {
    theme_primary: "#18181b",
    theme_primary_hover: "#27272a",
    theme_on_primary: "#ffffff",
    theme_bg: "#ffffff",
    theme_surface: "#ffffff",
    theme_surface_alt: "#fafafa",
    theme_border: "#e4e4e7",
    theme_text: "#18181b",
    theme_text_muted: "#52525b"
  }.freeze

  def up
    LANDING_THEME.each do |column, value|
      change_column_default :general_settings, column, from: PREVIOUS_THEME[column], to: value
    end

    GeneralSetting.reset_column_information
    GeneralSetting.update_all(LANDING_THEME) # rubocop:disable Rails/SkipsModelValidations
  end

  def down
    PREVIOUS_THEME.each do |column, value|
      change_column_default :general_settings, column, from: LANDING_THEME[column], to: value
    end

    GeneralSetting.reset_column_information
    GeneralSetting.update_all(PREVIOUS_THEME) # rubocop:disable Rails/SkipsModelValidations
  end
end
