class DefaultUnknownVehicleMake < ActiveRecord::Migration[7.0]
  def change
    change_column_default :bookings, :vehicle_make, from: nil, to: 'Unknown'
  end
end


