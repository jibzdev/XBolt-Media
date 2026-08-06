class CreateBusinesses < ActiveRecord::Migration[7.0]
  def change
    create_table :businesses do |t|
      t.string :name, null: false
      t.string :subdomain, null: false

      # Optional custom domain (e.g. client.com or www.client.com)
      t.string :custom_domain
      t.string :custom_domain_status, null: false, default: 'unverified'
      t.string :domain_verification_token

      t.timestamps
    end

    add_index :businesses, :subdomain, unique: true
    add_index :businesses, :custom_domain, unique: true
  end
end

