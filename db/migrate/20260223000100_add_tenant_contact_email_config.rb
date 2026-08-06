class AddTenantContactEmailConfig < ActiveRecord::Migration[7.0]
  def change
    add_column :businesses, :tenant_contact_sender_email, :string
    add_column :businesses, :tenant_contact_sender_password, :string
    add_column :businesses, :tenant_contact_recipient_email, :string

    add_reference :contact_messages, :business, foreign_key: true
    add_index :contact_messages, [:business_id, :ip_address, :created_at], name: 'index_contact_messages_on_business_ip_and_created'
  end
end
