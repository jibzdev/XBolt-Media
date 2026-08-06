class CreatePaymentModules < ActiveRecord::Migration[7.0]
  def change
    create_table :payment_modules do |t|
      t.string :name
      t.string :publishable_key
      t.string :secret_key

      t.timestamps
    end
  end
end
