class AddSocialLinksToGeneralSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :general_settings, :linkedin_url, :string
    add_column :general_settings, :facebook_url, :string
    add_column :general_settings, :instagram_url, :string
    add_column :general_settings, :tiktok_url, :string
    add_column :general_settings, :google_reviews_url, :string
  end
end
