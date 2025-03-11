class Account < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :destroy

  # Scope for plaid accounts
  scope :plaid_accounts, -> { where.not(plaid_token: nil) }

  def plaid_linked?
    plaid_account_id.present?
  end
end
