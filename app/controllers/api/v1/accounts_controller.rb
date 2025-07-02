module Api
  module V1
    class AccountsController < BaseController
      def index
        accounts = current_user.accounts.includes(:transactions)

        render_success(accounts.map { |a| serialize_account(a) })
      end

      def show
        account = current_user.accounts.find(params[:id])
        render_success(serialize_account(account, detailed: true))
      rescue ActiveRecord::RecordNotFound
        render_error("Account not found", :not_found)
      end

      def transactions
        account = current_user.accounts.find(params[:id])
        transactions = account.transactions.order(date: :desc).limit(100)

        render_success(transactions.map { |t|
          Api::V1::TransactionsController.new.send(:serialize_transaction, t)
        })
      rescue ActiveRecord::RecordNotFound
        render_error("Account not found", :not_found)
      end

      def balance_history
        account = current_user.accounts.find(params[:id])
        days = params[:days]&.to_i || 30

        history = calculate_balance_history(account, days)
        render_success(history)
      rescue ActiveRecord::RecordNotFound
        render_error("Account not found", :not_found)
      end

      private

      def serialize_account(account, detailed: false)
        data = {
          id: account.id,
          name: account.name,
          account_type: account.account_type,
          balance: account.balance.to_f,
          currency: account.currency || "USD",
          institution: account.institution,
          last_synced: account.last_synced_at,
          created_at: account.created_at,
          plaid_account_id: account.plaid_account_id
        }

        if detailed
          data[:recent_transactions] = account.transactions
                                              .order(date: :desc)
                                              .limit(10)
                                              .map { |t| Api::V1::TransactionsController.new.send(:serialize_transaction, t) }

          data[:monthly_summary] = {
            income: account.transactions.where("date >= ? AND amount > 0", 30.days.ago).sum(:amount),
            expenses: account.transactions.where("date >= ? AND amount < 0", 30.days.ago).sum(:amount).abs
          }
        end

        data
      end

      def calculate_balance_history(account, days)
        end_date = Date.current
        start_date = end_date - days.days

        transactions = account.transactions
                              .where("date >= ?", start_date)
                              .order(:date)

        # Calculate running balance
        current_balance = account.balance
        history = []

        (start_date..end_date).each do |date|
          day_transactions = transactions.select { |t| t.date == date }
          day_change = day_transactions.sum(&:amount)

          history << {
            date: date.to_s,
            balance: current_balance.to_f,
            change: day_change.to_f,
            transaction_count: day_transactions.count
          }

          current_balance -= day_change # Work backwards
        end

        history.reverse
      end
    end
  end
end