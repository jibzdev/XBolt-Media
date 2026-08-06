class AddAdminRoleToUsers < ActiveRecord::Migration[7.0]
  def up
    add_column :users, :admin_role, :string
    add_index :users, :admin_role

    execute <<~SQL.squish
      UPDATE users
      SET admin_role = 'admin'
      WHERE admin = TRUE AND (admin_role IS NULL OR admin_role = '')
    SQL
  end

  def down
    remove_index :users, :admin_role
    remove_column :users, :admin_role
  end
end
