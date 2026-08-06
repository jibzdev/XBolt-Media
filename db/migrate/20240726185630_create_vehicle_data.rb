
class CreateVehicleData < ActiveRecord::Migration[7.0]
  def change
    create_table :vehicle_data do |t|
      t.string :make, null: false
      t.string :model, null: false
      t.text :years
      t.text :colors

      t.timestamps
    end

    add_index :vehicle_data, [:make, :model], unique: true
    add_index :vehicle_data, :make
  end
end
