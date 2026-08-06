class EnforceUsernameLogins < ActiveRecord::Migration[7.0]
  def up
    # Backfill missing usernames
    say_with_time "Backfilling missing usernames" do
      User.reset_column_information

      User.where(username: [nil, '']).find_each do |u|
        base =
          if u.email.present?
            u.email.split('@').first.to_s.gsub(/[^a-zA-Z0-9_]/, '').presence || "user#{u.id}"
          else
            "user#{u.id}"
          end

        candidate = base
        counter = 1
        while User.where.not(id: u.id).exists?(username: candidate)
          candidate = "#{base}#{counter}"
          counter += 1
        end

        u.update_columns(username: candidate)
      end
    end

    change_column_null :users, :username, false

    # Enforce uniqueness at DB level
    add_index :users, :username, unique: true unless index_exists?(:users, :username, unique: true)
  end

  def down
    remove_index :users, :username if index_exists?(:users, :username)
    change_column_null :users, :username, true
  end
end

