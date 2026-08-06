class AddTenantImageFieldsToDemoWebsiteSettings < ActiveRecord::Migration[7.0]
  def change
    change_table :demo_website_settings, bulk: true do |t|
      t.integer :tenant_image_business_id
      t.text :image_slots_data, null: false, default: ""
    end
  end
end
