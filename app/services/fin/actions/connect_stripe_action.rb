module Fin
  module Actions
    class ConnectStripeAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "connect_stripe"
      end

      def perform
        success_response("data" => tool_result)
      end
    end
  end
end
