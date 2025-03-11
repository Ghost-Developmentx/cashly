class AddUniqueConstraintsToPlaidFields < ActiveRecord::Migration[8.0]
  def change
    add_index :accounts, :plaid_account_id, unique: true, where: "plaid_account_id IS NOT NULL"
    add_index :transactions, :plaid_transaction_id, unique: true, where: "plaid_transaction_id IS NOT NULL"
  end
end
