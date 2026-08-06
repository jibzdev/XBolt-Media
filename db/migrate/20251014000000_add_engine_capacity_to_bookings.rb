class AddEngineCapacityToBookings < ActiveRecord::Migration[7.0]
  def change
    add_column :bookings, :engine_capacity, :integer
  end
end


