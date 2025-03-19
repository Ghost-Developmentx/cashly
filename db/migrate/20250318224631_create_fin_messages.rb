class CreateFinMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :fin_messages do |t|
      t.references :fin_conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false
      t.text :metadata, default: "{}"
      t.timestamps
    end

    add_index :fin_conversations, [ :user_id, :active ]
  end
end
