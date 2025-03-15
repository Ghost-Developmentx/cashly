class CreateJournalEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :journal_entries do |t|
      t.date :date, null: false
      t.string :reference
      t.text :description
      t.string :status, default: 'draft'
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :journal_entries, :date
    add_index :journal_entries, :reference
    add_index :journal_entries, :status
  end
end
