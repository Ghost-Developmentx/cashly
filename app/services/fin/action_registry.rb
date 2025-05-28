module Fin
  class ActionRegistry
    class << self
      def actions
        @actions ||= {}
      end

      def register(tool_name, action_class)
        actions[tool_name.to_s] = action_class
        Rails.logger.info "[ActionRegistry] Registered: #{tool_name} -> #{action_class}"
      end

      def execute(tool_name, user, tool_result, params = {})
        # Ensure actions are loaded
        ensure_actions_loaded!

        Rails.logger.info "[ActionRegistry] Executing tool: #{tool_name}"
        Rails.logger.info "[ActionRegistry] Available actions: #{actions.keys.join(', ')}"

        action_class = actions[tool_name.to_s]

        unless action_class
          Rails.logger.warn "[ActionRegistry] No action registered for tool: #{tool_name}"
          Rails.logger.warn "[ActionRegistry] Tool result was: #{tool_result.inspect}"
          return nil
        end

        Rails.logger.info "[ActionRegistry] Found action class: #{action_class}"

        action_class.new(user, tool_result, params).execute
      rescue StandardError => e
        Rails.logger.error "[ActionRegistry] Error executing #{tool_name}: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        {
          "type" => "#{tool_name}_error",
          "success" => false,
          "error" => e.message
        }
      end

      private

      def ensure_actions_loaded!
        return if @actions_loaded

        # Manually register all actions if they haven't been registered yet
        if actions.empty?
          Rails.logger.info "[ActionRegistry] Loading actions..."

          # Define the mapping here
          action_mappings = {
            "get_transactions" => Fin::Actions::GetTransactionsAction,
            "get_user_accounts" => Fin::Actions::GetUserAccountsAction,
            "create_transaction" => Fin::Actions::CreateTransactionAction,
            "update_transaction" => Fin::Actions::UpdateTransactionAction,
            "delete_transaction" => Fin::Actions::DeleteTransactionAction,
            "categorize_transactions" => Fin::Actions::CategorizeTransactionsAction,
            "get_invoices" => Fin::Actions::GetInvoicesAction,
            "create_invoice" => Fin::Actions::CreateInvoiceAction,
            "send_invoice" => Fin::Actions::SendInvoiceAction,
            "delete_invoice" => Fin::Actions::DeleteInvoiceAction,
            "delete_invoice_completed" => Fin::Actions::DeleteInvoiceCompletedAction,
            "delete_invoice_failed" => Fin::Actions::DeleteInvoiceFailedAction,
            "send_invoice_initiated" => Fin::Actions::SendInvoiceInitiatedAction,
            "send_invoice_reminder" => Fin::Actions::SendInvoiceReminderAction,
            "mark_invoice_paid" => Fin::Actions::MarkInvoicePaidAction,
            "setup_stripe_connect" => Fin::Actions::SetupStripeConnectAction,
            "check_stripe_connect_status" => Fin::Actions::CheckStripeConnectStatusAction,
            "create_stripe_connect_dashboard_link" => Fin::Actions::CreateStripeConnectDashboardLinkAction,
            "initiate_plaid_connection" => Fin::Actions::InitiatePlaidConnectionAction
          }

          action_mappings.each do |tool_name, action_class|
            register(tool_name, action_class)
          end

          @actions_loaded = true
          Rails.logger.info "[ActionRegistry] Loaded #{actions.count} actions"
        end
      end
    end
  end
end
