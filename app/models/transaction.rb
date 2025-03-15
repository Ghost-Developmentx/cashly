class Transaction < ApplicationRecord
  belongs_to :account
  belongs_to :category, optional: true

  delegate :user, to: :account

  has_one :journal_entry, dependent: :nullify

  # Callbacks
  after_create :create_journal_entry
  after_update :update_journal_entry
  after_destroy :reverse_journal_entry

  scope :plaid_transactions, -> { where.not(plaid_transaction_id: nil) }

  def plaid_linked?
    plaid_transaction_id.present?
  end

  private

  def create_journal_entry
    return if journal_entry.present?
    return unless category_id.present?

    # Create a new journal entry
    entry = user.journal_entries.create(
      date: date,
      reference: "TXN-#{id}",
      description: description,
      status: JournalEntry::DRAFT
    )

    # Create appropriate journal lines based on transaction type
    if amount >= 0
      # Income transaction
      # Credit the income account
      income_account = category.primary_ledger_account
      entry.journal_lines.create(
        ledger_account: income_account,
        credit_amount: amount.abs,
        debit_amount: 0,
        description: "Income: #{description}"
      )

      # Debit the asset account
      asset_account = get_asset_account_for_bank_account
      entry.journal_lines.create(
        ledger_account: asset_account,
        debit_amount: amount.abs,
        credit_amount: 0,
        description: "Income to: #{account.name}"
      )
    else
      # Expense transaction
      # Debit the expense account
      expense_account = category.primary_ledger_account
      entry.journal_lines.create(
        ledger_account: expense_account,
        debit_amount: amount.abs,
        credit_amount: 0,
        description: "Expense: #{description}"
      )

      # Credit the asset account
      asset_account = get_asset_account_for_bank_account
      entry.journal_lines.create(
        ledger_account: asset_account,
        credit_amount: amount.abs,
        debit_amount: 0,
        description: "Expense from: #{account.name}"
      )
    end

    # Post the entry if it's balanced
    entry.post if entry.balanced?

    # Link the entry to this transaction
    update_column(:journal_entry_id, entry.id)
  end

  def update_journal_entry
    return unless journal_entry.present?

    # If the transaction was material changed, reverse the old entry and create a new one
    if saved_change_to_amount? || saved_change_to_date? || saved_change_to_category_id?
      reverse_journal_entry
      create_journal_entry
    end
  end

  def reverse_journal_entry
    return unless journal_entry.present?

    # Reverse the journal entry
    reversal = journal_entry.reverse

    # Unlink the journal entry
    update_column(:journal_entry_id, nil)
  end

  def get_asset_account_for_bank_account
    # Logic to map bank account to asset account
    # This could be based on a mapping table or convention

    # For now, we'll assume a simple mapping - this would need to be expanded
    asset_accounts = LedgerAccount.where(account_type: "asset")

    # Look for an asset account with matching name
    asset_account = asset_accounts.find_by("name ILIKE ?", "%#{account.name}%")

    # If not found, use a default cash account
    asset_account || asset_accounts.find_by(code: "1000") || asset_accounts.first
  end
end
