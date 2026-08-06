class CreatePaymentIpLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :payment_ip_logs do |t|
      t.references :payment, null: false, foreign_key: true
      t.string :ip_address

      t.timestamps
    end
  end
end
