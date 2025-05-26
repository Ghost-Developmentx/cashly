module Fin
  module Actions
    class CreateStripeConnectDashboardLinkAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "create_stripe_connect_dashboard_link"
      end

      def perform
        manager = Fin::StripeConnectManager.new(user)
        dashboard_result = manager.create_dashboard_link

        if dashboard_result[:success]
          success_response(
            "data" => dashboard_result,
            "message" => dashboard_result[:message] || "Opening your Stripe dashboard..."
          )
        else
          handle_dashboard_error(dashboard_result)
        end
      end

      private

      def handle_dashboard_error(result)
        case result[:action_needed]
        when "restart_setup"
          {
            "type" => "stripe_connect_setup_needed",
            "error" => result[:error],
            "message" => "You need to set up Stripe Connect first. Would you like me to start the setup process?"
          }
        else
          {
            "type" => "stripe_connect_error",
            "error" => result[:error],
            "message" => "I wasn't able to open your Stripe dashboard right now."
          }
        end
      end
    end
  end
end
