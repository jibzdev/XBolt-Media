class AddGoogleSecretToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :google_secret, :string
  end
end
