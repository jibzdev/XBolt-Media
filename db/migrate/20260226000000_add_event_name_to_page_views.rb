class AddEventNameToPageViews < ActiveRecord::Migration[7.0]
  def change
    add_column :page_views, :event_name, :string
    add_index :page_views, :event_name
    add_index :page_views, [:business_id, :event_name, :occurred_at], name: "index_page_views_on_business_event_and_time"
  end
end
