class CreateJournalLines < ActiveRecord::Migration[8.0]
  def change
    create_table :journal_lines do |t|
      t.references :journal_entry, null: false, foreign_key: true
      t.references :ledger_account, null: false, foreign_key: true
      t.decimal :debit_amount
      t.decimal :credit_amount
      t.text :description

      t.timestamps
    end
  end
end
