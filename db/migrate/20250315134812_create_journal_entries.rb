class CreateJournalEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :journal_entries do |t|
      t.date :date
      t.string :reference
      t.text :description
      t.string :status
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
