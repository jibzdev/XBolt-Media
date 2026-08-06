class AddThemeAndBrandingToGeneralSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :general_settings, :logo_url, :string
    add_column :general_settings, :favicon_url, :string

    add_column :general_settings, :theme_primary, :string, default: "#18181b", null: false
    add_column :general_settings, :theme_primary_hover, :string, default: "#27272a", null: false
    add_column :general_settings, :theme_on_primary, :string, default: "#ffffff", null: false

    add_column :general_settings, :theme_bg, :string, default: "#ffffff", null: false
    add_column :general_settings, :theme_surface, :string, default: "#ffffff", null: false
    add_column :general_settings, :theme_surface_alt, :string, default: "#fafafa", null: false
    add_column :general_settings, :theme_border, :string, default: "#e4e4e7", null: false

    add_column :general_settings, :theme_text, :string, default: "#18181b", null: false
    add_column :general_settings, :theme_text_muted, :string, default: "#52525b", null: false
  end
end

