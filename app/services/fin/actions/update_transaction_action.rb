module Fin
  module Actions
    class UpdateTransactionAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "update_transaction"
        raise "Transaction ID required" unless tool_result["transaction_id"].present?
        raise "Updates required" unless tool_result["updates"].present?
      end

      def perform
        result = Banking::UpdateTransaction.call(
          user: user,
          transaction_id: tool_result["transaction_id"],
          params: tool_result["updates"]
        )

        if result.success?
          success_response(
            "data" => {
              "transaction" => result.data[:transaction],
              "changes" => result.data[:changes]
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
