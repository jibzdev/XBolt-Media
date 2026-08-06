class AllowNullVehicleModel < ActiveRecord::Migration[7.0]
  def change
    change_column_null :bookings, :vehicle_model, true
  end
end


