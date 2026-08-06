class CreateSeoSettings < ActiveRecord::Migration[7.0]
  def change
    create_table :seo_settings do |t|
      t.string :page_name
      t.string :title
      t.text :description
      t.string :keywords

      t.timestamps
    end
  end
end
