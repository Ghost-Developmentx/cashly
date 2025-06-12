module Fin
  module Actions
    class SetupStripeConnectAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "setup_stripe_connect"
      end

      def perform
        result = Billing::GetStripeConnectStatus.call(user: user)

        if result.success? && result.data[:connected]
          {
            "type" => "show_stripe_connect_status",
            "success" => true,
            "data" => result.data,
            "message" => "Your Stripe Connect account is already set up and ready to accept payments!"
          }
        else
          {
            "type" => "setup_stripe_connect",
            "success" => true,
            "data" => tool_result.merge(result.data),
            "message" => "Let's set up Stripe Connect so you can accept payments through your invoices."
          }
        end
      end
    end
  end
end
