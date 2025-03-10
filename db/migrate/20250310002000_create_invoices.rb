class CreateInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :invoices do |t|
      t.references :user, null: false, foreign_key: true
      t.string :client_name
      t.decimal :amount
      t.date :issue_date
      t.date :due_date
      t.string :status

      t.timestamps
    end
  end
end
