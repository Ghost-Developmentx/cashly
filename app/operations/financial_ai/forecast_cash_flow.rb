module FinancialAI
  class ForecastCashFlow < BaseOperation
    attr_reader :user, :days, :scenario_adjustments

    validates :user, presence: true
    validates :days, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 365 }

    def initialize(user:, days: 30, scenario_adjustments: nil)
      @user = user
      @days = days
      @scenario_adjustments = scenario_adjustments
    end

    def execute
      transactions = fetch_historical_transactions

      if transactions.empty?
        return failure("Not enough transaction history to generate forecast")
      end

      forecast_data = if scenario_adjustments.present?
                        generate_scenario_forecast(transactions)
                      else
                        generate_standard_forecast(transactions)
                      end

      if forecast_data[:error].present?
        failure(forecast_data[:error])
      else
        success(
          forecast: format_forecast_data(forecast_data),
          message: "Generated #{days}-day cash flow forecast"
        )
      end
    end

    private

    def fetch_historical_transactions
      user.transactions
          .where("date >= ?", 6.months.ago)
          .order(date: :asc)
    end

    def generate_standard_forecast(transactions)
      AiService.forecast_cash_flow(
        user.id,
        format_transactions_for_ai(transactions),
        days
      )
    end

    def generate_scenario_forecast(transactions)
      AiService.forecast_cash_flow_scenario(
        user.id,
        format_transactions_for_ai(transactions),
        days,
        scenario_adjustments
      )
    end

    def format_transactions_for_ai(transactions)
      transactions.map do |t|
        {
          date: t.date,
          amount: t.amount,
          category: t.category&.name || "uncategorized"
        }
      end
    end

    def format_forecast_data(raw_forecast)
      {
        id: "forecast-#{Time.current.to_i}",
        title: "#{days}-Day Cash Flow Forecast",
        forecast_days: days,
        daily_forecast: raw_forecast["daily_forecast"] || [],
        summary: raw_forecast["summary"] || {},
        confidence_score: raw_forecast["confidence_score"] || 0.7,
        generated_at: Time.current.iso8601,
        scenario: scenario_adjustments
      }
    end
  end
end
