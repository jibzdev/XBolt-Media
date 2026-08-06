class AddLayoutNameToDemoWebsiteSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :demo_website_settings, :layout_name, :string, null: false, default: "show"
  end
end
