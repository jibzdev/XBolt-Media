class CreatePageViews < ActiveRecord::Migration[7.0]
  def change
    create_table :page_views do |t|
      t.references :business, null: true, foreign_key: true
      t.string :path, null: false
      t.string :host, null: false
      t.string :referrer
      t.string :user_agent
      t.string :ip_hash
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :page_views, :occurred_at
    add_index :page_views, [:business_id, :occurred_at]
  end
end

