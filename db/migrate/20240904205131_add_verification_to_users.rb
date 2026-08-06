class AddVerificationToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :verification_token, :string
    add_column :users, :verification_sent_at, :datetime
  end
end
