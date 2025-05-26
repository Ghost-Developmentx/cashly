module Fin
  module Actions
    class SetupStripeConnectAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "setup_stripe_connect"
      end

      def perform
        manager = Fin::StripeConnectManager.new(user)
        connect_status = manager.status

        if connect_status[:connected]
          success_response(
            "data" => connect_status,
            "message" => "Your Stripe Connect account is already set up and ready to accept payments!"
          )
        else
          success_response(
            "data" => tool_result.merge(connect_status)
          )
        end
      end
    end
  end
end
