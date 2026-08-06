class DropPaymentModules < ActiveRecord::Migration[7.0]
  def change
    drop_table :payment_modules, if_exists: true
  end
end
