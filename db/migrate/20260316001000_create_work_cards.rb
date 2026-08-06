class CreateWorkCards < ActiveRecord::Migration[7.0]
  def change
    create_table :work_cards do |t|
      t.string :name, null: false
      t.string :domain_url, null: false
      t.string :image_url
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :work_cards, :active
    add_index :work_cards, :position
  end
end
