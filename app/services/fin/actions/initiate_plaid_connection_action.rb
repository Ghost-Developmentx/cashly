module Fin
  module Actions
    class InitiatePlaidConnectionAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "initiate_plaid_connection"
      end

      def perform
        success_response(
          "action" => "initiate_plaid_connection",
          "data" => tool_result,
          "user_id" => tool_result["user_id"]
        )
      end
    end
  end
end
