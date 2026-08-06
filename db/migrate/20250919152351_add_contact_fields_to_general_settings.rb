class AddContactFieldsToGeneralSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :general_settings, :phone_number, :string
    add_column :general_settings, :contact_email, :string
    add_column :general_settings, :website_url, :string
  end
end
