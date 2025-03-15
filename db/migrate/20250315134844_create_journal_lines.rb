class CreateJournalLines < ActiveRecord::Migration[8.0]
  def change
    create_table :journal_lines do |t|
      t.references :journal_entry, null: false, foreign_key: true
      t.references :ledger_account, null: false, foreign_key: true
      t.decimal :debit_amount, precision: 15, scale: 2, default: 0
      t.decimal :credit_amount, precision: 15, scale: 2, default: 0
      t.text :description

      t.timestamps
    end

    add_index :journal_lines, [:journal_entry_id, :ledger_account_id]
  end
end
