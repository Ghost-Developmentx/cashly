module Ai
  class InsightsController < ApplicationController
    before_action :authenticate_user!

    def index
      @insights = []

      # Get recent transactions
      @recent_transactions = current_user.transaction.order(date: :desc).limit(100)

      # Only proceed if we have any transactions
      if @recent_transactions.present?
        # Get financial trends
        trends_response = AiService.analyze_trends(
          current_user.id,
          @recent_transactions,
          params[:period] || "3m"
        )

        @trends = trends_response.is_a?(Hash) ? trends_response : {}
        @insights = @trends.dig("insights") || []
      end

      respond_to do |format|
        format.html
        format.json { render json: { insights: @insights, trends: @trends } }
      end
    end

    def forecast
      @forecast = {}

      @historical_transactions = current_user.transaction.order(date: :asc)

      # Only proceed if there are transactions
      if @historical_transactions.present?

        forecast_response = AiService.forecast_cash_flow(
        current_user.id,
        @historical_transactions,
        params[:days].to_i || 30
        )

        @forecast = forecast_response.is_a?(Hash) ? forecast_response : {}
      end

      respond_to do |format|
        format.html
        format.json { render json: forecast }
      end
    end

    def recommendations
      @budget_recommendations = {}

      # Get user transactions for budget analysis
      @budget_transactions = current_user.transaction.where("date >= ?", 3.months.ago)

      # Calculate monthly income (only positive transactions)
      monthly_income = current_user.transaction.where("date >= ? AND amount > 0", 1.month.ago).sum(:amount)

      # Only proceed if we have transactions and income
      if @budget_transactions.present? && monthly_income > 0

        budget_response = AiService.generate_budget(
        current_user.id,
        @budget_transactions,
        monthly_income,
        )

        @budget_recommendations = budget_response.is_a?(Hash) ? budget_response : {}
      end

      respond_to do |format|
        format.html
        format.json { render json: @budget_recommendations }
      end
    end
  end
end
