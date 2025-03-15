# app/models/journal_line.rb
class JournalLine < ApplicationRecord
  belongs_to :journal_entry
  belongs_to :ledger_account

  # Set default values for amounts
  after_initialize :set_default_values, if: :new_record?

  # Validations
  validates :ledger_account, presence: true
  validates :debit_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :credit_amount, numericality: { greater_than_or_equal_to: 0 }
  validate :valid_amount
  validate :valid_entry_status

  # Callbacks
  before_save :ensure_amount_matches_account_type

  # Methods
  def amount
    debit_amount > 0 ? debit_amount : credit_amount
  end

  private

  def set_default_values
    self.debit_amount ||= 0
    self.credit_amount ||= 0
  end

  def valid_amount
    if debit_amount > 0 && credit_amount > 0
      errors.add(:base, "A journal line cannot have both debit and credit amounts")
    elsif debit_amount == 0 && credit_amount == 0
      errors.add(:base, "A journal line must have either a debit or a credit amount")
    end
  end

  def valid_entry_status
    if journal_entry&.status != JournalEntry::DRAFT && (changed? || new_record?)
      errors.add(:base, "Cannot modify lines for a posted or reversed journal entry")
    end
  end

  def ensure_amount_matches_account_type
    # This method adds accounting effect information

    if ledger_account.default_balance == "debit"
      # For asset and expense accounts
      self.is_increase = (debit_amount > 0)
    else
      # For liability, equity, and revenue accounts
      self.is_increase = (credit_amount > 0)
    end

    # Calculate the net effect on the account balance
    if ledger_account.default_balance == "debit"
      self.net_amount = debit_amount - credit_amount
    else
      self.net_amount = credit_amount - debit_amount
    end
  end
end