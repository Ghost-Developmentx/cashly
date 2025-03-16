class BankStatement < ApplicationRecord
  belongs_to :account
  has_many :transactions, dependent: :nullify

  validates :account_id, presence: true
  validates :statement_date, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :ending_balance, presence: true

  validate :end_date_after_start_date

  scope :by_account, ->(account_id) { where(account_id: account_id) }
  scope :recent_first, -> { order(statement_date: :desc) }

  def reconciled?
    transactions.where(reconciled: true).count > 0
  end

  def reconciliation_progress
    # Get transactions within the statement's date range
    statement_transactions = account.transactions.where(date: start_date..end_date)
    return 0 if statement_transactions.empty?

    # Calculate percentage of reconciled transactions
    reconciled_count = statement_transactions.where(reconciled: true, bank_statement_id: id).count
    (reconciled_count.to_f / statement_transactions.count) * 100
  end

  def fully_reconciled?
    statement_transactions = account.transactions.where(date: start_date..end_date)
    return false if statement_transactions.empty?

    reconciled_count = statement_transactions.where(reconciled: true, bank_statement_id: id).count
    reconciled_count == statement_transactions.count
  end

  def reconciliation_difference
    statement_transactions = account.transactions.where(date: start_date..end_date)
    reconciled_balance = statement_transactions.where(reconciled: true, bank_statement_id: id).sum(:amount)
    ending_balance - reconciled_balance
  end

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    if end_date < start_date
      errors.add(:end_date, "must be after the start date")
    end
  end
end
