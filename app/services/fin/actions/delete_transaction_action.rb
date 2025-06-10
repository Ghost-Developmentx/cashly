module Fin
  module Actions
    class DeleteTransactionAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "delete_transaction"
        raise "Transaction ID required" unless tool_result["transaction_id"].present?
      end

      def perform
        result = Banking::DeleteTransaction.call(
          user: user,
          transaction_id: tool_result["transaction_id"]
        )

        if result.success?
          success_response(
            "data" => {
              "deleted_transaction" => result.data[:deleted_transaction]
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
