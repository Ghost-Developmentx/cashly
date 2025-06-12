module Fin
  module Actions
    class CheckStripeConnectStatusAction < BaseAction
      def perform
        result = Billing::GetStripeConnectStatus.call(user: user)

        if result.success?
          success_response(
            "data" => result.data,
            "message" => result.data[:status_message]
          )
        else
          error_response(result.error)
        end
      end
    end
  end
end
