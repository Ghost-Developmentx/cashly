Dir[Rails.root.join("app/services/fin/actions/*.rb")].each { |f| require f }

Rails.application.config.after_initialize do
  Rails.logger.info "[ActionRegistry] Initializing action registry..."

  # Register all actions
  Fin::ActionRegistry.register("get_transactions", Fin::Actions::GetTransactionsAction)
  Fin::ActionRegistry.register("get_user_accounts", Fin::Actions::GetUserAccountsAction)
  Fin::ActionRegistry.register("create_transaction", Fin::Actions::CreateTransactionAction)
  Fin::ActionRegistry.register("update_transaction", Fin::Actions::UpdateTransactionAction)
  Fin::ActionRegistry.register("delete_transaction", Fin::Actions::DeleteTransactionAction)
  Fin::ActionRegistry.register("categorize_transactions", Fin::Actions::CategorizeTransactionsAction)
  Fin::ActionRegistry.register("get_invoices", Fin::Actions::GetInvoicesAction)
  Fin::ActionRegistry.register("create_invoice", Fin::Actions::CreateInvoiceAction)
  Fin::ActionRegistry.register("send_invoice", Fin::Actions::SendInvoiceAction)
  Fin::ActionRegistry.register("delete_invoice", Fin::Actions::DeleteInvoiceAction)
  Fin::ActionRegistry.register("delete_invoice_completed", Fin::Actions::DeleteInvoiceCompletedAction)
  Fin::ActionRegistry.register("delete_invoice_failed", Fin::Actions::DeleteInvoiceFailedAction)
  Fin::ActionRegistry.register("send_invoice_initiated", Fin::Actions::SendInvoiceInitiatedAction)
  Fin::ActionRegistry.register("send_invoice_reminder", Fin::Actions::SendInvoiceReminderAction)
  Fin::ActionRegistry.register("mark_invoice_paid", Fin::Actions::MarkInvoicePaidAction)
  Fin::ActionRegistry.register("setup_stripe_connect", Fin::Actions::SetupStripeConnectAction)
  Fin::ActionRegistry.register("check_stripe_connect_status", Fin::Actions::CheckStripeConnectStatusAction)
  Fin::ActionRegistry.register("create_stripe_connect_dashboard_link", Fin::Actions::CreateStripeConnectDashboardLinkAction)
  Fin::ActionRegistry.register("initiate_plaid_connection", Fin::Actions::InitiatePlaidConnectionAction)

  Rails.logger.info "[ActionRegistry] Registered #{Fin::ActionRegistry.actions.count} actions"
  Rails.logger.info "[ActionRegistry] Actions: #{Fin::ActionRegistry.actions.keys.join(', ')}"
end
