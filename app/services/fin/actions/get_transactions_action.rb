module Fin
  module Actions
    class GetTransactionsAction < BaseAction
      def perform
        # If we have pre-fetched transactions, use them
        if tool_result["transactions"].present?
          # This is from the AI service with pre-fetched data
          return success_response(
            "data" => {
              "transactions" => tool_result["transactions"],
              "summary" => tool_result["summary"] || calculate_summary(tool_result["transactions"])
            }
          )
        end

        # Otherwise fetch using our operation
        filters = tool_result["filters"] || {}
        result = Banking::ListTransactions.call(
          user: user,
          filters: filters
        )

        if result.success?
          success_response(
            "data" => result.data
          )
        else
          error_response(result.error)
        end
      end

      private

      def calculate_summary(transactions)
        # Basic summary calculation for pre-fetched data
        total_income = transactions.select { |t| t["amount"].to_f > 0 }.sum { |t| t["amount"].to_f }
        total_expenses = transactions.select { |t| t["amount"].to_f < 0 }.sum { |t| t["amount"].to_f.abs }

        {
          count: transactions.size,
          total_income: total_income,
          total_expenses: total_expenses,
          net_change: total_income - total_expenses
        }
      end
    end
  end
end
