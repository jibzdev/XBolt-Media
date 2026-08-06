class AddImageUrlToSeoSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :seo_settings, :image_url, :string
  end
end
