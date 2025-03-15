class AddSourceTransactionToJournalEntries < ActiveRecord::Migration[8.0]
  def change
    add_reference :journal_entries, :source_transaction, foreign_key: { to_table: :transactions }, null: true
  end
end
