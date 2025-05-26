module Fin
  module Actions
    class GetTransactionsAction < BaseAction
      def perform
        return error_response("No transactions found") unless tool_result["transactions"].present?

        log_info "Found #{tool_result['transactions'].length} transactions"

        success_response(
          "data" => {
            "transactions" => format_transactions(tool_result["transactions"]),
            "summary" => tool_result["summary"] || calculate_summary(tool_result["transactions"])
          }
        )
      end

      private

      def format_transactions(transactions)
        transactions.map do |transaction|
          {
            id: transaction["id"] || transaction[:id],
            amount: transaction["amount"].to_f,
            description: transaction["description"],
            date: transaction["date"],
            category: transaction["category"] || "Uncategorized",
            account_name: transaction["account"] || transaction["account_name"],
            recurring: transaction["recurring"] || false,
            editable: !transaction["plaid_transaction_id"].present?,
            plaid_synced: transaction["plaid_transaction_id"].present?,
            ai_categorized: transaction["ai_categorized"] || false,
            created_at: transaction["created_at"]
          }
        end
      end

      def calculate_summary(transactions)
        total_income = transactions.select { |t| t["amount"].to_f > 0 }.sum { |t| t["amount"].to_f }
        total_expenses = transactions.select { |t| t["amount"].to_f < 0 }.sum { |t| t["amount"].to_f.abs }

        category_breakdown = {}
        transactions.select { |t| t["amount"].to_f < 0 }.each do |t|
          category = t["category"] || "Uncategorized"
          category_breakdown[category] = (category_breakdown[category] || 0) + t["amount"].to_f.abs
        end

        {
          count: transactions.size,
          total_income: total_income,
          total_expenses: total_expenses,
          net_change: total_income - total_expenses,
          date_range: determine_date_range(transactions),
          category_breakdown: category_breakdown
        }
      end

      def determine_date_range(transactions)
        return "No transactions" if transactions.empty?

        dates = transactions.map { |t| Date.parse(t["date"]) }
        start_date = dates.min
        end_date = dates.max

        "#{start_date.strftime('%b %d, %Y')} to #{end_date.strftime('%b %d, %Y')}"
      end
    end
  end
end
