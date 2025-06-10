module FinancialAI
  class ConversationContext
    attr_reader :user, :conversation

    def initialize(user, conversation = nil)
      @user = user
      @conversation = conversation
    end

    def build
      {
        user_id: user.id.to_s,
        conversation_id: conversation&.id,
        user_context: build_user_context,
        transactions: build_transactions,
        timestamp: Time.current.iso8601
      }
    end

    private

    def build_user_context
      {
        user_id: user.id.to_s,
        name: user.full_name,
        email: user.email,
        currency: user.currency || "USD",
        timezone: user.timezone || "America/New_York",
        accounts: build_accounts,
        budgets: build_budgets,
        invoice_stats: build_invoice_stats,
        stripe_connect: user.stripe_connect_status,
        integrations: build_integrations,
        member_since: user.created_at.strftime("%B %Y")
      }
    end

    def build_accounts
      user.accounts.map do |account|
        {
          id: account.id,
          name: account.name,
          type: account.account_type,
          balance: account.balance.to_f,
          institution: account.institution,
          last_synced: account.last_synced&.iso8601,
          plaid_connected: account.plaid_account_id.present?
        }
      end
    end

    def build_transactions
      TransactionQuery.new(user.transactions)
                      .with_filters(days: 180) # Last 6 months
                      .execute
                      .limit(100)
                      .map { |t| format_transaction(t) }
    end

    def format_transaction(transaction)
      {
        id: transaction.id,
        date: transaction.date.strftime("%Y-%m-%d"),
        amount: transaction.amount.to_f,
        description: transaction.description,
        category: transaction.category&.name || "uncategorized",
        account: transaction.account.name,
        account_id: transaction.account.id,
        recurring: transaction.recurring || false,
        plaid_transaction_id: transaction.plaid_transaction_id
      }
    end

    def build_budgets
      user.budgets.includes(:category).map do |budget|
        {
          id: budget.id,
          category: budget.category.name,
          amount: budget.amount.to_f,
          period: "monthly"
        }
      end
    end

    def build_invoice_stats
      invoices = user.invoices

      {
        total_count: invoices.count,
        pending_count: invoices.pending.count,
        pending_amount: invoices.pending.sum(:amount).to_f,
        paid_count: invoices.paid.count,
        paid_amount: invoices.paid.sum(:amount).to_f,
        overdue_count: invoices.overdue.count,
        draft_count: invoices.draft.count
      }
    end

    def build_integrations
      user.integrations.active.map do |integration|
        {
          provider: integration.provider,
          status: integration.status,
          connected_at: integration.connected_at&.iso8601
        }
      end
    end
  end
end
