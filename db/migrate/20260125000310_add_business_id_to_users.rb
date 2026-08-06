class AddBusinessIdToUsers < ActiveRecord::Migration[7.0]
  def change
    # add_reference already creates an index by default.
    # Guard everything so re-running migrations won't error.
    unless column_exists?(:users, :business_id)
      add_reference :users, :business, null: true, foreign_key: false, index: false
    end

    add_index :users, :business_id unless index_exists?(:users, :business_id)
    add_foreign_key :users, :businesses unless foreign_key_exists?(:users, :businesses)
  end
end

