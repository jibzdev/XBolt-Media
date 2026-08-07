class CreateTenantSitePages < ActiveRecord::Migration[7.0]
  def up
    create_table :tenant_site_pages, if_not_exists: true do |t|
      t.references :business, null: false, foreign_key: true
      t.string :title, null: false
      t.string :slug, null: false
      t.integer :position, null: false, default: 0
      t.json :sections, null: false, default: []
      t.datetime :published_at

      t.timestamps
    end

    add_index :tenant_site_pages, [:business_id, :slug], unique: true, if_not_exists: true
    add_index :tenant_site_pages, [:business_id, :position], if_not_exists: true
  end

  def down
    drop_table :tenant_site_pages, if_exists: true
  end
end
