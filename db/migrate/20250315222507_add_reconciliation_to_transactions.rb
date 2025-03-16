class AddReconciliationToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :reconciled, :boolean, default: false
    add_column :transactions, :reconciled_at, :datetime
    add_column :transactions, :reconciliation_notes, :text
    add_column :transactions, :statement_id, :integer
    add_index :transactions, :reconciled
    add_index :transactions, :statement_id
  end
end
