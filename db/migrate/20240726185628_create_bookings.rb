class CreateBookings < ActiveRecord::Migration[7.0]
  def change
    create_table :bookings do |t|
      t.references :user, null: true, foreign_key: true
      t.string :service_type, null: false
      t.string :vehicle_make, null: false
      t.string :vehicle_model, null: false
      t.integer :vehicle_year, null: false
      t.string :vehicle_color
      t.text :special_requests
      t.datetime :appointment_date, null: false
      t.decimal :estimated_cost, precision: 10, scale: 2
      t.decimal :final_cost, precision: 10, scale: 2
      t.string :status, default: 'pending'
      
      # Guest booking fields
      t.string :customer_name
      t.string :customer_email
      t.string :customer_phone

      t.timestamps
    end

    add_index :bookings, :appointment_date
    add_index :bookings, :status
    add_index :bookings, :service_type
  end
end
