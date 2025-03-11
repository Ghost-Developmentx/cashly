class CreatePlaidTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :plaid_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :access_token
      t.string :item_id

      t.timestamps
    end

    add_index :plaid_tokens, :item_id, unique: true
  end
end
