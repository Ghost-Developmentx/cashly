class UpdatePlaidTokensForEncryption < ActiveRecord::Migration[8.0]
  def change
    rename_column :plaid_tokens, :access_token, :encrypted_access_token
    add_column :plaid_tokens, :encrypted_access_token_iv, :string
  end
end
