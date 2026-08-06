class CreateContactMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :contact_messages do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.text :message, null: false
      t.string :ip_address, null: false
      t.string :user_agent
      t.datetime :read_at

      t.timestamps
    end

    add_index :contact_messages, [:ip_address, :created_at]
    add_index :contact_messages, :read_at
    add_index :contact_messages, :created_at
  end
end
