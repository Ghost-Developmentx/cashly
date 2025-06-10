module Fin
  module Actions
    class CategorizeTransactionsAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "categorize_transactions"
      end

      def perform
        result = Banking::CategorizeTransactions.call(
          user: user,
          transaction_ids: tool_result["transaction_ids"]
        )

        if result.success?
          success_response(
            "data" => {
              "count" => result.data[:count]
            },
            "message" => result.data[:message]
          )
        else
          error_response(result.error)
        end
      end
    end
  end
end
