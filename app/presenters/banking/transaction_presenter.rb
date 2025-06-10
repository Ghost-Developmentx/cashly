module Banking
  class TransactionPresenter
    def initialize(transaction)
      @transaction = transaction
    end

    def as_json(options = {})
      {
        id: @transaction.id,
        amount: @transaction.amount.to_f,
        description: @transaction.description,
        date: @transaction.date.strftime("%Y-%m-%d"),
        category: @transaction.category&.name || "Uncategorized",
        category_id: @transaction.category_id,
        account: account_info,
        recurring: @transaction.recurring || false,
        ai_categorized: @transaction.ai_categorized || false,
        editable: @transaction.plaid_transaction_id.blank?,
        plaid_synced: @transaction.plaid_transaction_id.present?,
        created_at: @transaction.created_at.iso8601,
        type: transaction_type
      }.merge(options)
    end

    private

    def account_info
      {
        id: @transaction.account.id,
        name: @transaction.account.name,
        type: @transaction.account.account_type
      }
    end

    def transaction_type
      @transaction.amount > 0 ? "income" : "expense"
    end
  end
end
