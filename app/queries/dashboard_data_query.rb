class DashboardDataQuery < ApplicationQuery
  attr_reader :user

  validates :user, presence: true

  def initialize(user:)
    @user = user
  end

  def execute
    {
      accounts_summary: fetch_accounts_summary,
      recent_transactions: fetch_recent_transactions,
      spending_by_category: fetch_spending_by_category,
      invoice_summary: fetch_invoice_summary,
      cash_flow_summary: fetch_cash_flow_summary
    }
  end

  private

  def fetch_accounts_summary
    Rails.cache.fetch("dashboard/#{user.id}/accounts", expires_in: 5.minutes) do
      {
        total_balance: user.accounts.sum(:balance),
        account_count: user.accounts.count,
        last_sync: user.accounts.maximum(:last_synced)
      }
    end
  end

  def fetch_recent_transactions
    user.transactions
        .includes(:category, :account)
        .order(date: :desc)
        .limit(10)
        .map { |t| Banking::TransactionPresenter.new(t).as_json }
  end

  def fetch_spending_by_category
    Rails.cache.fetch("dashboard/#{user.id}/spending/#{Date.current.month}", expires_in: 1.hour) do
      user.transactions
          .joins(:category)
          .where(date: Date.current.beginning_of_month..Date.current.end_of_month)
          .where("amount < 0")
          .group("categories.name")
          .sum("ABS(amount)")
    end
  end

  def fetch_invoice_summary
    {
      pending_count: user.invoices.pending.count,
      pending_amount: user.invoices.pending.sum(:amount),
      paid_this_month: user.invoices.paid
                           .where(updated_at: Date.current.beginning_of_month..Date.current.end_of_month)
                           .sum(:amount)
    }
  end

  def fetch_cash_flow_summary
    income = user.transactions
                 .where(date: Date.current.beginning_of_month..Date.current.end_of_month)
                 .where("amount > 0")
                 .sum(:amount)

    expenses = user.transactions
                   .where(date: Date.current.beginning_of_month..Date.current.end_of_month)
                   .where("amount < 0")
                   .sum(:amount).abs

    {
      income: income,
      expenses: expenses,
      net: income - expenses
    }
  end
end
