class AddClerkIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :clerk_id, :string
    add_index :users, :clerk_id
  end
end
