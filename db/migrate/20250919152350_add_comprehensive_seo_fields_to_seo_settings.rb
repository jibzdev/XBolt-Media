class AddComprehensiveSeoFieldsToSeoSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :seo_settings, :author, :string
    add_column :seo_settings, :robots, :string, default: 'index, follow'
    add_column :seo_settings, :og_type, :string, default: 'website'
    add_column :seo_settings, :og_url, :string
    add_column :seo_settings, :og_title, :string
    add_column :seo_settings, :og_description, :text
    add_column :seo_settings, :og_image, :string
    add_column :seo_settings, :twitter_card, :string, default: 'summary_large_image'
    add_column :seo_settings, :twitter_url, :string
    add_column :seo_settings, :twitter_title, :string
    add_column :seo_settings, :twitter_description, :text
    add_column :seo_settings, :twitter_image, :string
    add_column :seo_settings, :favicon_url, :string
    add_column :seo_settings, :apple_touch_icon_url, :string
    add_column :seo_settings, :canonical_url, :string
    add_column :seo_settings, :structured_data, :text
  end
end
