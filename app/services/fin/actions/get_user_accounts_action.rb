module Fin
  module Actions
    class GetUserAccountsAction < BaseAction
      def perform
        return error_response("No accounts found") unless tool_result["accounts"].present?

        log_info "Found #{tool_result['accounts'].length} accounts"

        {
          "type" => "show_accounts",
          "success" => true,
          "data" => { "accounts" => tool_result["accounts"] },
          "message" => "Found #{tool_result['accounts'].length} connected account#{tool_result['accounts'].length == 1 ? '' : 's'}"
        }
      end
    end
  end
end
