class CreateLedgerAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :ledger_accounts do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :account_type, null: false
      t.string :account_subtype
      t.text :description
      t.references :parent_account, null: true, foreign_key: { to_table: :ledger_accounts }
      t.boolean :active, null: false, default: true
      t.string :default_balance, null: false, default: "debit"
      t.integer :display_order

      t.timestamps
    end

    add_index :ledger_accounts, :code, unique: true
    add_index :ledger_accounts, [:account_type, :account_subtype]
    add_index :ledger_accounts, :active
  end
end
