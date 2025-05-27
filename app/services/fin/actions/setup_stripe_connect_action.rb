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
        {
          "type" => "show_stripe_connect_status",
          "success" => true,
          "data" => connect_status,
          "message" => "Your Stripe Connect account is already set up and ready to accept payments!"
        }
      else
        {
          "type" => "setup_stripe_connect",
          "success" => true,
          "data" => tool_result.merge(connect_status),
          "message" => "Let's set up Stripe Connect so you can accept payments through your invoices."
        }
      end
    end
  end
end
end