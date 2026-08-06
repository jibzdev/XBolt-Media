class CreateDemoWebsiteSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :demo_website_settings do |t|
      t.string :site_title, null: false, default: "Your Business Name"
      t.string :hero_badge, null: false, default: "Template Preview"
      t.string :hero_heading, null: false, default: "Your business, beautifully presented"
      t.text :hero_subheading, null: false, default: "Show clients how their future website could look with your service."
      t.string :cta_primary_text, null: false, default: "Get Quote"
      t.string :cta_secondary_text, null: false, default: "View Work"
      t.string :about_title, null: false, default: "About Your Business"
      t.text :about_body, null: false, default: "Replace this with business-specific details in the admin dashboard."
      t.string :theme_name, null: false, default: "violet"
      t.string :contact_email, null: false, default: "you@example.com"
      t.string :contact_phone, null: false, default: "+44 7000 000000"

      t.timestamps
    end
  end
end
