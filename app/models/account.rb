class Account < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :destroy
  has_many :bank_statements, dependent: :destroy

  # Scope for plaid accounts
  scope :plaid_accounts, -> { where.not(plaid_account_id: nil) }

  def plaid_linked?
    plaid_account_id.present?
  end
end
