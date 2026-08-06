class AddWorkFieldsToBusinesses < ActiveRecord::Migration[7.0]
  def change
    add_column :businesses, :description, :text
    add_column :businesses, :image_url, :string
    add_column :businesses, :active, :boolean, null: false, default: false

    add_index :businesses, :active
  end
end

