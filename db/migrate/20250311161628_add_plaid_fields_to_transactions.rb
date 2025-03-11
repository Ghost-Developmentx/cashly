class AddPlaidFieldsToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :plaid_transaction_id, :string
  end
end
