class AddStripeChargeIdToPayments < ActiveRecord::Migration[7.0]
  def change
    add_column :payments, :stripe_charge_id, :string
  end
end
