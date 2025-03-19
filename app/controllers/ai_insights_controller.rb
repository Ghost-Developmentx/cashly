module Ai
  class InsightsController < ApplicationController
    before_action :authenticate_user!

    def index
      @insights = []

      # Get recent transactions
      @recent_transactions = current_user.transactions.order(date: :desc).limit(500)
      @period = params[:period] || "3m"

      # Only proceed if we have any transactions
      if @recent_transactions.present?
        # Format transactions for AI service
        formatted_transactions = @recent_transactions.map do |t|
          {
            id: t.id,
            date: t.date.to_s,
            amount: t.amount.to_f,
            description: t.description,
            category: t.category&.name || "uncategorized"
          }
        end

        # Get financial trends
        trends_response = AiService.analyze_trends(
          current_user.id,
          formatted_transactions,
          @period
        )

        @trends = trends_response.is_a?(Hash) ? trends_response : {}
        @insights = @trends.dig("insights") || []

        # Get anomalies
        anomalies_response = AiService.detect_anomalies(
          current_user.id,
          formatted_transactions
        )

        @anomalies = anomalies_response.is_a?(Hash) ? anomalies_response : {}
      end

      respond_to do |format|
        format.html
        format.json { render json: { insights: @insights, trends: @trends, anomalies: @anomalies } }
      end
    end

    def forecast
      @forecast = {}

      @historical_transactions = current_user.transactions.order(date: :asc).limit(1000)

      # Only proceed if there are transactions
      if @historical_transactions.present?
        # Format transactions for AI service
        formatted_transactions = @historical_transactions.map do |t|
          {
            id: t.id,
            date: t.date.to_s,
            amount: t.amount.to_f,
            description: t.description,
            category: t.category&.name || "uncategorized"
          }
        end

        forecast_response = AiService.forecast_cash_flow(
          current_user.id,
          formatted_transactions,
          params[:days].to_i || 30
        )

        @forecast = forecast_response.is_a?(Hash) ? forecast_response : {}
      end

      respond_to do |format|
        format.html
        format.json { render json: @forecast }
      end
    end

    def recommendations
      @budget_recommendations = {}

      # Get user transactions for budget analysis
      @budget_transactions = current_user.transactions.where("date >= ?", 3.months.ago)

      # Calculate monthly income (only positive transactions)
      monthly_income = current_user.transactions.where("date >= ? AND amount > 0", 1.month.ago).sum(:amount)

      # Only proceed if we have transactions and income
      if @budget_transactions.present? && monthly_income > 0
        # Format transactions for AI service
        formatted_transactions = @budget_transactions.map do |t|
          {
            id: t.id,
            date: t.date.to_s,
            amount: t.amount.to_f,
            description: t.description,
            category: t.category&.name || "uncategorized"
          }
        end

        budget_response = AiService.generate_budget(
          current_user.id,
          formatted_transactions,
          monthly_income
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