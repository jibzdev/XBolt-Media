class CreateGeneralSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :general_settings do |t|
      t.string :application_name, default: "XBolt"

      t.timestamps
    end
  end
end
