module Fin
  module Actions
    class GetUserAccountsAction < BaseAction
      def perform
        # If we have pre-fetched accounts from AI context
        if tool_result["accounts"].present?
          return success_response(
            "data" => { "accounts" => tool_result["accounts"] },
            "message" => "Found #{tool_result['accounts'].length} connected account#{tool_result['accounts'].length == 1 ? '' : 's'}"
          )
        end

        # Otherwise fetch using operation
        result = Banking::ListAccounts.call(user: user)

        if result.success?
          {
            "type" => "show_accounts",
            "success" => true,
            "data" => { "accounts" => result.data[:accounts] },
            "message" => "Found #{result.data[:accounts].length} connected account#{result.data[:accounts].length == 1 ? '' : 's'}"
          }
        else
          error_response(result.error)
        end
      end
    end
  end
end
