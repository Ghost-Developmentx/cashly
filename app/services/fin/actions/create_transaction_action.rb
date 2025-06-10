module Fin
  module Actions
    class CreateTransactionAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "create_transaction"
        raise "Transaction data required" unless tool_result["transaction"].present?
      end

      def perform
        result = Banking::CreateTransaction.call(
          user: user,
          params: tool_result["transaction"]
        )

        if result.success?
          success_response(
            "data" => {
              "transaction" => result.data[:transaction]
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
