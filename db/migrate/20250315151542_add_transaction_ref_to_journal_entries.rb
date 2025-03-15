class AddTransactionRefToJournalEntries < ActiveRecord::Migration[8.0]
  def change
    add_reference :journal_entries, :transaction, foreign_key: true, null: true
  end
end
