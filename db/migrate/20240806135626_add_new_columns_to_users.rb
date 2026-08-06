class AddNewColumnsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :receive_email_notifications, :boolean, default: true
    add_column :users, :admin, :boolean, default: false
  end
end
