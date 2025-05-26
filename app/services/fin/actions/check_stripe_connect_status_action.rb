module Fin
  module Actions
    class CheckStripeConnectStatusAction < BaseAction
      def perform
        manager = Fin::StripeConnectManager.new(user)
        connect_status = manager.status

        success_response(
          "data" => connect_status
        )
      end
    end
  end
end
