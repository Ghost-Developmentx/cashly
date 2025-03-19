class CreateFinConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :fin_conversations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.boolean :active, default: true
      t.timestamps
    end
  end
end
