module Fin
  module Actions
    class ForecastCashFlowAction < BaseAction
      def perform
        days = tool_result["forecast_days"] || 30

        result = FinancialAI::ForecastCashFlow.call(
          user: user,
          days: days
        )

        if result.success?
          {
            "type" => "show_forecast",
            "success" => true,
            "data" => transform_forecast_data(result.data[:forecast]),
            "message" => result.data[:message]
          }
        else
          error_response(result.error)
        end
      end

      private

      def transform_forecast_data(forecast)
        {
          "id" => forecast[:id],
          "title" => forecast[:title],
          "dataPoints" => transform_daily_forecast(forecast[:daily_forecast]),
          "summary" => {
            "totalProjected" => forecast[:summary]["projected_net"] || 0,
            "averageDaily" => calculate_daily_average(forecast[:daily_forecast]),
            "trend" => detect_trend(forecast[:daily_forecast]),
            "confidenceScore" => forecast[:confidence_score],
            "periodDays" => forecast[:forecast_days]
          },
          "generatedAt" => forecast[:generated_at]
        }
      end

      def transform_daily_forecast(daily_data)
        return [] unless daily_data.is_a?(Array)

        daily_data.map do |day|
          {
            "date" => day["date"],
            "predicted" => day["net_change"] || 0,
            "confidence" => day["confidence"] || 0.8
          }
        end
      end

      def calculate_daily_average(daily_data)
        return 0 unless daily_data.is_a?(Array) && daily_data.any?

        total = daily_data.sum { |day| day["net_change"] || 0 }
        (total / daily_data.size).round(2)
      end

      def detect_trend(daily_data)
        return "stable" unless daily_data.is_a?(Array) && daily_data.size >= 7

        first_week = daily_data.first(7)
        last_week = daily_data.last(7)

        first_avg = first_week.sum { |d| d["net_change"] || 0 } / 7.0
        last_avg = last_week.sum { |d| d["net_change"] || 0 } / 7.0

        if last_avg > first_avg * 1.1
          "up"
        elsif last_avg < first_avg * 0.9
          "down"
        else
          "stable"
        end
      end
    end
  end
end
