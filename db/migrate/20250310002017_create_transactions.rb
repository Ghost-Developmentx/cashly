class CreateTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.decimal :amount
      t.datetime :date
      t.text :description
      t.references :category, null: false, foreign_key: true
      t.boolean :recurring

      t.timestamps
    end
  end
end
