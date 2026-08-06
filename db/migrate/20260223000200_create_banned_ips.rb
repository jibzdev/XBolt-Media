class CreateBannedIps < ActiveRecord::Migration[7.0]
  def change
    create_table :banned_ips do |t|
      t.string :ip_address, null: false
      t.text :reason
      t.references :banned_by, null: true, foreign_key: { to_table: :users }
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :banned_ips, :ip_address, unique: true
  end
end
