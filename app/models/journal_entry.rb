# app/models/journal_entry.rb
class JournalEntry < ApplicationRecord
  belongs_to :user
  has_many :journal_lines, dependent: :destroy

  # Validations
  validates :date, presence: true
  validates :status, inclusion: { in: %w[draft posted reversed] }

  # Status constants
  DRAFT = 'draft'
  POSTED = 'posted'
  REVERSED = 'reversed'

  # Scopes
  scope :draft, -> { where(status: DRAFT) }
  scope :posted, -> { where(status: POSTED) }
  scope :reversed, -> { where(status: REVERSED) }
  scope :for_period, ->(start_date, end_date) { where(date: start_date..end_date) }

  # Methods
  def total_debits
    journal_lines.sum(:debit_amount)
  end

  def total_credits
    journal_lines.sum(:credit_amount)
  end

  def balanced?
    total_debits == total_credits
  end

  def post
    return false unless draft?
    return false unless balanced?

    update(status: POSTED)
  end

  def reverse
    return false unless posted?

    # Create a reversal entry
    reversal = user.journal_entries.create(
      date: Date.today,
      reference: "REV-#{reference}",
      description: "Reversal of #{reference}: #{description}",
      status: DRAFT
    )

    # Create reversal lines (flip debits and credits)
    journal_lines.each do |line|
      reversal.journal_lines.create(
        ledger_account: line.ledger_account,
        debit_amount: line.credit_amount,
        credit_amount: line.debit_amount,
        description: "Reversal of: #{line.description}"
      )
    end

    # Post the reversal entry
    reversal.post

    # Mark original as reversed
    update(status: REVERSED)

    reversal
  end

  private

  def draft?
    status == DRAFT
  end

  def posted?
    status == POSTED
  end
end
