class CreateBankStatements < ActiveRecord::Migration[7.0]
  def change
    create_table :bank_statements do |t|
      t.references :account, null: false, foreign_key: true
      t.date :statement_date, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.decimal :ending_balance, precision: 15, scale: 2, null: false
      t.decimal :starting_balance, precision: 15, scale: 2
      t.string :statement_number
      t.string :reference
      t.string :file_path
      t.text :notes
      t.boolean :locked, default: false

      t.timestamps
    end

    add_index :bank_statements, [ :account_id, :statement_date ]
  end
end
