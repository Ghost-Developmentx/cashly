class Transaction < ApplicationRecord
  belongs_to :account
  belongs_to :category, optional: true

  delegate :user, to: :account

  scope :plaid_transactions, -> { where.not(plaid_transaction_id: nil) }

  def plaid_linked?
    plaid_transaction_id.present?
  end
end
