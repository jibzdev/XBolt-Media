class CreatePayments < ActiveRecord::Migration[7.0]
  def change
    create_table :payments do |t|
      t.integer :user_id
      t.integer :product_id
      t.string :status
      t.decimal :amount
      t.string :payment_type
      t.string :stripe_session_id

      t.timestamps
    end
  end
end
