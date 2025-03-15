class AddJournalEntryToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_reference :transactions, :journal_entry, null: true, foreign_key: true
  end
end
