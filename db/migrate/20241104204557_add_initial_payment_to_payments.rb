class AddInitialPaymentToPayments < ActiveRecord::Migration[7.0]
  def change
    add_column :payments, :initial_payment, :boolean, default: false
  end
end
