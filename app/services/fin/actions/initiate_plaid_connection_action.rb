module Fin
  module Actions
    class InitiatePlaidConnectionAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "initiate_plaid_connection"
      end

      def perform
        result = Banking::CreatePlaidLinkToken.call(user: user)

        if result.success?
          success_response(
            "action" => "initiate_plaid_connection",
            "data" => {
              "link_token" => result.data[:link_token],
              "user_id" => user.id
            }
          )
        else
          error_response(result.error)
        end
      end
    end
  end
end