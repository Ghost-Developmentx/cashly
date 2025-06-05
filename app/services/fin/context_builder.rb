module Fin
  class ContextBuilder
    def initialize(user)
      @user = user
    end

    def build
      {
        transactions: build_transactions,
        user_context: build_user_context
      }
    end

    private

    def build_transactions
      transactions = @user.transactions
                          .includes(:category, :account)
                          .where("date >= ?", 6.months.ago)
                          .order(date: :desc)
                          .limit(100)

      Rails.logger.info "[ContextBuilder] Found #{transactions.count} transactions for user #{@user.id}"

      formatted_transactions = transactions.map { |t| format_transaction(t) }

      if formatted_transactions.any?
        Rails.logger.info "[ContextBuilder] Sample transaction: #{formatted_transactions.first.inspect}"
      end

      formatted_transactions
    end

    def build_user_context
      {
        accounts: @user.accounts.map { |a| format_account(a) },
        budgets: @user.budgets.map { |b| format_budget(b) },
        stripe_connect: @user.stripe_connect_status,
        invoice_stats: calculate_invoice_stats,
        currency: @user.currency
      }
    end

    def format_transaction(transaction)
      {
        id: transaction.id,
        date: transaction.date.to_s,
        amount: transaction.amount.to_f,
        description: transaction.description,
        category: transaction.category&.name || "uncategorized",
        account: transaction.account.name,
        account_id: transaction.account.id
      }
    end

    def format_account(account)
      {
        id: account.id,
        name: account.name,
        type: account.account_type,
        balance: account.balance.to_f,
        institution: account.institution
      }
    end

    def format_budget(budget)
      {
        id: budget.id,
        category: budget.category.name,
        amount: budget.amount.to_f
      }
    end

    def calculate_invoice_stats
      {
        total_count: @user.invoices.count,
        pending_count: @user.invoices.pending.count,
        paid_amount: @user.invoices.paid.sum(:amount).to_f,
        draft_count: @user.invoices.draft.count
      }
    end
  end
end
