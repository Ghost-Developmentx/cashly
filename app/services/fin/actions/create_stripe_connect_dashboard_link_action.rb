module Fin
  module Actions
    class CreateStripeConnectDashboardLinkAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "create_stripe_connect_dashboard_link"
      end

      def perform
        result = Billing::CreateStripeDashboardLink.call(user: user)

        if result.success?
          {
            "type" => "open_stripe_dashboard",
            "success" => true,
            "data" => result.data,
            "message" => result.data[:message]
          }
        else
          handle_dashboard_error(result)
        end
      end

      private

      def handle_dashboard_error(result)
        if result.error.include?("No Stripe Connect account")
          {
            "type" => "stripe_connect_setup_needed",
            "success" => false,
            "error" => result.error,
            "message" => "You need to set up Stripe Connect first. Would you like me to start the setup process?"
          }
        else
          {
            "type" => "stripe_connect_error",
            "success" => false,
            "error" => result.error,
            "message" => "I wasn't able to open your Stripe dashboard right now."
          }
        end
      end
    end
  end
end
