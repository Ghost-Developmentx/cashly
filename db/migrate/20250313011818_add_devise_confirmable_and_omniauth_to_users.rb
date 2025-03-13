class AddDeviseConfirmableAndOmniauthToUsers < ActiveRecord::Migration[8.0]
  def change
    # For confirmable
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string

    # For omniauthable
    add_column :users, :provider, :string
    add_column :users, :uid, :string

    # Add indexes
    add_index :users, :confirmation_token, unique: true
    add_index :users, [ :provider, :uid ]
  end
end
