class RemoveStripeArtifacts < ActiveRecord::Migration[7.0]
  def change
    drop_table :stripe_settings, if_exists: true

    remove_column :users, :stripe_customer_id, :string if column_exists?(:users, :stripe_customer_id)
    remove_column :payments, :stripe_session_id, :string if column_exists?(:payments, :stripe_session_id)
    remove_column :payments, :stripe_charge_id, :string if column_exists?(:payments, :stripe_charge_id)
  end
end
