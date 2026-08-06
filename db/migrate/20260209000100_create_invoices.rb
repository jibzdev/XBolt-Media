class CreateInvoices < ActiveRecord::Migration[7.0]
  def change
    create_table :invoices do |t|
      t.references :business, null: false, foreign_key: true
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :invoice_number, null: false
      t.string :status, null: false, default: 'draft'
      t.date :issue_date, null: false
      t.date :due_date, null: false
      t.json :line_items, null: false, default: []
      t.decimal :subtotal, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total, precision: 12, scale: 2, null: false, default: 0
      t.text :notes
      t.string :share_token, null: false

      t.timestamps
    end

    add_index :invoices, :invoice_number, unique: true
    add_index :invoices, :share_token, unique: true
    add_index :invoices, :status
  end
end
