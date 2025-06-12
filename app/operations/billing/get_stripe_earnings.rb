module Billing
  class GetStripeEarnings < BaseOperation
    attr_reader :user, :period

    validates :user, presence: true
    validates :period, inclusion: { in: %w[week month quarter year] }

    def initialize(user:, period: "month")
      @user = user
      @period = period
    end

    def execute
      connect_account = user.stripe_connect_account

      unless connect_account&.can_accept_payments?
        return failure("Stripe Connect account not ready for earnings reporting")
      end

      earnings_data = fetch_earnings(connect_account)

      success(
        earnings: earnings_data,
        period: period
      )
    rescue Stripe::StripeError => e
      failure("Failed to fetch earnings: #{e.message}")
    end

    private

    def fetch_earnings(connect_account)
      date_range = calculate_date_range

      # Get balance transactions from Stripe
      transactions = fetch_balance_transactions(
        connect_account.stripe_account_id,
        date_range[:start_date],
        date_range[:end_date]
      )

      # Calculate earnings
      calculate_earnings_summary(transactions, date_range)
    end

    def calculate_date_range
      end_date = Date.current
      start_date = case period
                   when "week" then 1.week.ago.to_date
                   when "month" then 1.month.ago.to_date
                   when "quarter" then 3.months.ago.to_date
                   when "year" then 1.year.ago.to_date
                   else 1.month.ago.to_date
                   end

      { start_date: start_date, end_date: end_date }
    end

    def fetch_balance_transactions(account_id, start_date, end_date)
      Stripe::BalanceTransaction.list(
        {
          created: {
            gte: start_date.to_time.to_i,
            lte: end_date.to_time.to_i
          },
          limit: 100
        },
        { stripe_account: account_id }
      ).data
    end

    def calculate_earnings_summary(transactions, date_range)
      total_gross = 0
      total_fees = 0
      total_net = 0
      platform_fees_earned = 0
      transaction_count = 0

      transactions.each do |txn|
        if txn.type == "charge"
          total_gross += txn.amount
          total_fees += txn.fee
          total_net += txn.net
          transaction_count += 1
        elsif txn.type == "application_fee"
          platform_fees_earned += txn.amount
        end
      end

      {
        period: period,
        date_range: "#{date_range[:start_date].strftime('%B %d, %Y')} - #{date_range[:end_date].strftime('%B %d, %Y')}",
        total_gross: total_gross / 100.0,
        total_fees: total_fees / 100.0,
        total_net: total_net / 100.0,
        platform_fees_earned: platform_fees_earned / 100.0,
        transaction_count: transaction_count,
        average_transaction: transaction_count > 0 ? (total_gross / transaction_count / 100.0) : 0
      }
    end
  end
end
