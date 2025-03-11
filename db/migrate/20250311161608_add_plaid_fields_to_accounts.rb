class AddPlaidFieldsToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :plaid_account_id, :string
    add_column :accounts, :last_synced_at, :datetime
  end
end
