class DashboardController < ApplicationController
  before_action :authenticate_user!
  def index
    # Calculate user account balances
    @total_balance = current_user.accounts.sum(&:balance)

    # Calculate monthly income and expenses
    month_start = Time.now.beginning_of_month
    month_end = Time.now.end_of_month

    @monthly_income = current_user.transactions
                                  .where("date >= ? AND date <= ? AND amount > 0", month_start, month_end)
                                  .sum(:amount)

    @monthly_expenses = current_user.transactions
                                    .where("date >= ? AND date <= ? AND amount < 0", month_start, month_end)
                                    .sum(:amount).abs

    # Get financial insights from AI service if we have transactions
    if current_user.transactions.exists?
      recent_transactions = current_user.transactions.order(date: :desc).limit(100)

      trends_response = AiService.analyze_trends(
        current_user.id,
        recent_transactions,
        "3m"
      )

      # If API call was successful, extract insights
      if trends_response.is_a?(Hash) && !trends_response[:error]
        @insights = trends_response["insights"] || []
      else
        @insights = []
      end
    else
      @insights = []
    end
  end
end
