class CreateStripeConnectAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :stripe_connect_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :stripe_account_id
      t.string :account_type
      t.string :country
      t.string :email
      t.string :business_type
      t.json :capabilities
      t.json :requirements
      t.string :charges_enabled
      t.string :payouts_enabled
      t.string :details_submitted
      t.datetime :created_at_stripe
      t.json :settings
      t.decimal :platform_fee_percentage
      t.string :status
      t.text :status_reason
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :stripe_connect_accounts, :stripe_account_id, unique: true
    add_index :stripe_connect_accounts, :status
  end
end
