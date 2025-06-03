module Fin
  module Actions
    class ForecastCashFlowScenarioAction < ForecastCashFlowAction
      def perform
        return error_response("No scenario forecast data") unless tool_result.present?

        log_info "Processing scenario forecast with adjustments"

        # Use parent's transform method
        forecast_data = transform_forecast_data(tool_result)

        # Add scenario-specific data
        if tool_result["scenario"]
          forecast_data["scenarios"] = {
            "base" => forecast_data["dataPoints"],
            "adjusted" => forecast_data["dataPoints"]
          }

          forecast_data["adjustments"] = parse_adjustments(tool_result["scenario"]["adjustments_applied"])
        end

        {
          "type" => "show_scenario_forecast",
          "success" => true,
          "data" => forecast_data,
          "message" => "Here's your adjusted forecast scenario"
        }
      end

      private

      def parse_adjustments(adjustments)
        return [] unless adjustments.is_a?(Hash)

        result = []

        if adjustments["income_adjustment"]
          result << {
            "type" => "income",
            "amount" => adjustments["income_adjustment"],
            "description" => "Income adjustment"
          }
        end

        if adjustments["expense_adjustment"]
          result << {
            "type" => "expense",
            "amount" => adjustments["expense_adjustment"],
            "description" => "Expense adjustment"
          }
        end

        if adjustments["category_adjustments"].is_a?(Hash)
          adjustments["category_adjustments"].each do |category, amount|
            result << {
              "type" => "expense",
              "category" => category,
              "amount" => amount,
              "description" => "#{category} adjustment"
            }
          end
        end

        result
      end
    end
  end
end
