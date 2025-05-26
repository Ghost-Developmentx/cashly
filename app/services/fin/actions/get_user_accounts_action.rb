module Fin
  module Actions
    class GetUserAccountsAction < BaseAction
      def perform
        return error_response("No accounts found") unless tool_result["accounts"].present?

        log_info "Found #{tool_result['accounts'].length} accounts"

        success_response(
          "data" => { "accounts" => tool_result["accounts"] }
        )
      end
    end
  end
end
