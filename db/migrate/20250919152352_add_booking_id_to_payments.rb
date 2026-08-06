class AddBookingIdToPayments < ActiveRecord::Migration[7.0]
  def change
    add_column :payments, :booking_id, :integer
    add_index :payments, :booking_id
  end
end
