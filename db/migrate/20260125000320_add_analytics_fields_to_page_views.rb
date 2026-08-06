class AddAnalyticsFieldsToPageViews < ActiveRecord::Migration[7.0]
  def change
    add_column :page_views, :country_code, :string
    add_column :page_views, :device_type, :string
    add_column :page_views, :browser, :string
    add_column :page_views, :os, :string
    add_column :page_views, :referrer_domain, :string

    add_index :page_views, :country_code unless index_exists?(:page_views, :country_code)
    add_index :page_views, :device_type unless index_exists?(:page_views, :device_type)
    add_index :page_views, :referrer_domain unless index_exists?(:page_views, :referrer_domain)
  end
end

