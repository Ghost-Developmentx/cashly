class CreateIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :integrations do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :status, default: 'active'
      t.text :credentials, null: false
      t.datetime :connected_at
      t.datetime :last_used_at
      t.datetime :expires_at
      t.text :metadata, default: "{}"

      t.timestamps
    end

    add_index :integrations, [ :user_id, :provider ], unique: true
    add_index :integrations, :status
  end
end
