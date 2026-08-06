class AddSourceToReviews < ActiveRecord::Migration[7.0]
  def change
    add_column :reviews, :source, :string, null: false, default: "google"
    add_index :reviews, :source
  end
end
