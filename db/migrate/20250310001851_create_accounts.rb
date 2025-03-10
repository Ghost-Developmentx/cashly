class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :account_type
      t.decimal :balance
      t.string :institution
      t.datetime :last_synced

      t.timestamps
    end
  end
end
