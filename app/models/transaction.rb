class Transaction < ApplicationRecord
  belongs_to :account
  belongs_to :category, optional: true
  belongs_to :bank_statement, optional: true

  delegate :user, to: :account

  has_many :journal_entries, foreign_key: "source_transaction_id", dependent: :nullify

  def active_journal_entry
    journal_entries.where(status: JournalEntry::POSTED).order(created_at: :desc).first
  end

  # Callbacks
  after_create :create_journal_entry
  after_update :update_journal_entry
  after_destroy :reverse_journal_entry

  scope :plaid_transactions, -> { where.not(plaid_transaction_id: nil) }

  # Reconciliation-related scopes
  scope :reconciled, -> { where(reconciled: true) }
  scope :unreconciled, -> { where(reconciled: false) }
  scope :for_account, ->(account_id) { joins(:account).where(accounts: { id: account_id }) }
  scope :in_date_range, ->(start_date, end_date) { where("date >= ? AND date <= ?", start_date, end_date) }


  def plaid_linked?
    plaid_transaction_id.present?
  end

  def reconcile(bank_statement_id = nil, notes = nil)
    update(
      reconciled: true,
      reconciled_at: Time.current,
      reconciliation_notes: notes,
      bank_statement_id: bank_statement_id
    )
  end

  def unreconcile
    update(
      reconciled: false,
      reconciled_at: nil,
      reconciliation_notes: nil,
      bank_statement_id: nil
    )
  end

  private

  def create_journal_entry
    return if active_journal_entry.present?
    return unless category_id.present?

    # Create a new journal entry
    entry = user.journal_entries.create(
      date: date,
      reference: "TXN-#{id}",
      description: description,
      status: JournalEntry::DRAFT,
      source_transaction_id: id
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
    current_entry = active_journal_entry
    return unless current_entry.present?

    # If the transaction was materially changed, reverse the old entry and create a new one
    if saved_change_to_amount? || saved_change_to_date? || saved_change_to_category_id? || saved_change_to_account_id?
      current_entry.reverse
      # Let the create_journal_entry method handle creating the new entry
      create_journal_entry
    end
  end

  def reverse_journal_entry
    current_entry = active_journal_entry
    return unless current_entry.present?

    # Reverse the journal entry
    current_entry.reverse
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
