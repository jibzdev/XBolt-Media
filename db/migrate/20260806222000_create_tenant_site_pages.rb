class CreateTenantSitePages < ActiveRecord::Migration[7.0]
  def change
    create_table :tenant_site_pages do |t|
      t.references :business, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.integer :position, null: false, default: 0
      t.json :sections, null: false, default: []
      t.datetime :published_at

      t.timestamps
    end

    add_index :tenant_site_pages, [:business_id, :slug], unique: true
    add_index :tenant_site_pages, [:business_id, :position]
  end
end
