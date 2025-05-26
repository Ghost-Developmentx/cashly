module Fin
  class DataFetcher < BaseService
    def initialize(user)
      @user = user
    end

    def fetch_transactions
      log_info "Fetching transactions for user #{@user.id}"

      start_date = 6.months.ago.to_date
      transactions = @user.transactions
                          .where("date >= ?", start_date)
                          .includes(:category, :account)
                          .order(date: :desc)

      log_info "Found #{transactions.count} transactions from #{start_date} to #{Date.current}"
      log_transaction_samples(transactions)

      format_transactions(transactions)
    end

    def fetch_user_context
      log_info "Fetching user context for user #{@user.id}"

      {
        accounts: fetch_accounts,
        budgets: fetch_budgets,
        forecasts: fetch_forecasts,
        stripe_connect: fetch_stripe_connect_status,
        integrations: fetch_integrations,
        invoice_stats: fetch_invoice_stats,
        currency: @user.currency || "USD",
        name: @user.full_name
      }.tap do |context|
        log_context_summary(context)
      end
    end

    private

    def format_transactions(transactions)
      transactions.map do |t|
        {
          id: t.id,
          date: t.date.strftime("%Y-%m-%d"),
          amount: t.amount.to_f,
          description: t.description,
          category: t.category&.name || "uncategorized",
          account: t.account.name,
          account_id: t.account.id,
          recurring: t.recurring,
          plaid_transaction_id: t.plaid_transaction_id
        }
      end
    end

    def log_transaction_samples(transactions)
      transactions.limit(3).each_with_index do |t, i|
        log_info "Transaction #{i}: ID=#{t.id}, Date=#{t.date}, Account=#{t.account.name} (ID=#{t.account.id}), Amount=#{t.amount}"
      end
    end

    def fetch_accounts
      @user.accounts.map do |a|
        account_data = {
          name: a.name,
          type: a.account_type,
          balance: a.balance.to_f,
          id: a.id,
          institution: a.institution,
          plaid_account_id: a.plaid_account_id
        }
        log_info "Account: ID=#{account_data[:id]}, Name='#{account_data[:name]}'"
        account_data
      end
    end

    def fetch_budgets
      @user.budgets.includes(:category).map do |b|
        {
          category: b.category.name,
          amount: b.amount.to_f,
          id: b.id
        }
      end
    end

    def fetch_forecasts
      @user.forecasts.order(created_at: :desc).limit(3).map do |f|
        {
          name: f.name,
          time_horizon: f.time_horizon,
          id: f.id,
          scenario_type: f.scenario_type
        }
      end
    end

    def fetch_stripe_connect_status
      status = @user.stripe_connect_status

      # Log the status for debugging
      log_info "Stripe Connect status for user #{@user.id}: connected=#{status[:connected]}, can_accept_payments=#{status[:can_accept_payments]}"

      status
    end

    def fetch_integrations
      @user.integrations.active.map do |integration|
        {
          provider: integration.provider,
          status: integration.status,
          last_used: integration.last_used_at
        }
      end
    end

    def fetch_invoice_stats
      invoices = @user.invoices
      {
        total_count: invoices.count,
        pending_count: invoices.where(status: "pending").count,
        pending_amount: invoices.where(status: "pending").sum(:amount).to_f,
        overdue_count: invoices.where("status = 'pending' AND due_date < ?", Date.current).count,
        paid_count: invoices.where(status: "paid").count,
        paid_amount: invoices.where(status: "paid").sum(:amount).to_f,
        draft_count: invoices.where(status: "draft").count
      }
    end

    def log_context_summary(context)
      log_info "User context: #{context[:accounts].count} accounts, #{context[:budgets].count} budgets, #{context[:integrations].count} integrations"
    end
  end
end
