class AddMaintenanceModeToGeneralSettings < ActiveRecord::Migration[7.0]
  def change
    add_column :general_settings, :maintenance_mode, :boolean
  end
end
