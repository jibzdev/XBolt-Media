class AddLicensePlateToBookings < ActiveRecord::Migration[7.0]
  def change
    add_column :bookings, :license_plate, :string
  end
end
