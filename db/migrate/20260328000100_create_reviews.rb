class CreateReviews < ActiveRecord::Migration[7.0]
  def change
    create_table :reviews do |t|
      t.references :business, foreign_key: true
      t.string     :reviewer_name,  null: false
      t.string     :company_name
      t.text       :review_text,    null: false
      t.integer    :rating,         null: false, default: 5
      t.string     :avatar_url
      t.boolean    :active,         null: false, default: true
      t.integer    :position,       null: false, default: 0
      t.timestamps
    end

    add_index :reviews, :active
    add_index :reviews, :position
  end
end
