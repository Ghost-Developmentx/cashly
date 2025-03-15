class CreateCategoryAccountMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :category_account_mappings do |t|
      t.references :category, null: false, foreign_key: true
      t.references :ledger_account, null: false, foreign_key: true

      t.timestamps
    end

    add_index :category_account_mappings, [:category_id, :ledger_account_id], unique: true, name: 'index_category_ledger_account_unique'
  end
end
