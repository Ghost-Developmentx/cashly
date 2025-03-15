class AddAccountingEffectFieldsToJournalLines < ActiveRecord::Migration[8.0]
  def change
    add_column :journal_lines, :is_increase, :boolean, default: true
    add_column :journal_lines, :net_amount, :decimal, precision: 15, scale: 2, default: 0

    # Add an index to improve query performance when analyzing account impacts
    add_index :journal_lines, :is_increase
  end
end
