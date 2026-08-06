class CreateIpLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :ip_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.datetime :login_time

      t.timestamps
    end
  end
end
