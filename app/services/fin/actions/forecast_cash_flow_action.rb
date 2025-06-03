module Fin
  module Actions
    class ForecastCashFlowAction < BaseAction
      def perform
        return error_response("No forecast data") unless tool_result.present?

        log_info "Processing forecast with #{tool_result['forecast_days']} days"

        # Transform the forecast data to frontend format
        forecast_data = transform_forecast_data(tool_result)

        {
          "type" => "show_forecast",
          "success" => true,
          "data" => forecast_data,
          "message" => "Here's your #{tool_result['forecast_days']}-day cash flow forecast"
        }
      end

      private

      def transform_forecast_data(raw_forecast)
        {
          "id" => "forecast-#{Time.current.to_i}",
          "title" => "#{raw_forecast['forecast_days']}-Day Cash Flow Forecast",
          "dataPoints" => transform_daily_forecast(raw_forecast["daily_forecast"]),
          "summary" => {
            "totalProjected" => raw_forecast.dig("summary", "projected_net") || 0,
            "averageDaily" => calculate_daily_average(raw_forecast["daily_forecast"]),
            "trend" => detect_trend(raw_forecast["daily_forecast"]),
            "confidenceScore" => raw_forecast.dig("summary", "confidence_score") || 0.7,
            "periodDays" => raw_forecast["forecast_days"]
          },
          "generatedAt" => Time.current.iso8601
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
