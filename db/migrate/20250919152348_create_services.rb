class CreateServices < ActiveRecord::Migration[7.0]
  def change
    create_table :services do |t|
      t.string :name, null: false
      t.decimal :base_price, precision: 10, scale: 2, null: false
      t.string :category, null: false
      t.text :description
      t.boolean :active, default: true
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :services, :category
    add_index :services, :active
    add_index :services, :position
  end
end
