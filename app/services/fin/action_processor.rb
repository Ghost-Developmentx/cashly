module Fin
  class ActionProcessor < BaseService
    def initialize(user)
      @user = user
    end

    def process_ai_response(response)
      log_info "Processing AI response for UI"
      log_info "Input - tool_results: #{response['tool_results']&.length || 0}, actions: #{response['actions']&.length || 0}"

      return response unless response["tool_results"].present?

      response["actions"] ||= []

      response["tool_results"].each do |tool_result|
        action = process_tool_result(tool_result)
        response["actions"] << action if action
      end

      enhance_with_links(response)
      log_info "Output - actions: #{response['actions'].length}"

      response
    end

    private

    def process_tool_result(tool_result)
      tool_name = tool_result["tool"]
      result = tool_result["result"]

      log_info "Processing tool: #{tool_name}"
      log_info "Result keys: #{result.keys}" if result.is_a?(Hash)

      case tool_name
      when "get_transactions"
        process_transactions_result(result)
      when "get_user_accounts"
        process_accounts_result(result)
      when "create_transaction"
        process_transaction_creation(result)
      when "update_transaction"
        process_transaction_update(result)
      when "delete_transaction"
        process_transaction_deletion(result)
      when "categorize_transactions"
        process_transaction_categorization(result)
      when "connect_stripe"
        process_stripe_connection(result)
      when "get_invoices"
        process_invoices_result(result)
      when "create_invoice"
        process_invoice_creation(result)
      when "send_invoice"
        process_invoice_send(result)
      when "send_invoice_reminder"
        process_reminder_result(result)
      when "mark_invoice_paid"
        process_invoice_payment(result)
      when "setup_stripe_connect"
        process_stripe_connect_setup(result)
      when "check_stripe_connect_status"
        process_stripe_connect_status(result)
      when "create_stripe_connect_dashboard_link"
        process_dashboard_link(result)
      when "initiate_plaid_connection"
        process_plaid_connection(result)
      else
        log_info "Unknown tool: #{tool_name}"
        nil
      end
    end

    def process_transactions_result(result)
      return nil unless result["transactions"].present?

      log_info "Found #{result['transactions'].length} transactions"
      {
        "type" => "show_transactions",
        "data" => {
          "transactions" => format_transactions_for_display(result["transactions"]),
          "summary" => result["summary"] || calculate_summary_from_transactions(result["transactions"])
        }
      }
    end

    def process_accounts_result(result)
      return nil unless result["accounts"].present?

      log_info "Found #{result['accounts'].length} accounts"
      {
        "type" => "show_accounts",
        "data" => { "accounts" => result["accounts"] }
      }
    end

    def process_transaction_creation(result)
      return nil unless result["action"] == "create_transaction"

      created_transaction = Fin::TransactionExecutor.new(@user).create(result["transaction"])
      if created_transaction[:success]
        {
          "type" => "transaction_created",
          "data" => created_transaction,
          "message" => "Transaction created successfully!"
        }
      else
        {
          "type" => "transaction_error",
          "error" => created_transaction[:error]
        }
      end
    end

    def process_transaction_update(result)
      return nil unless result["action"] == "update_transaction"

      updated_transaction = Fin::TransactionExecutor.new(@user).update(result["transaction_id"], result["updates"])
      if updated_transaction[:success]
        {
          "type" => "transaction_updated",
          "data" => updated_transaction,
          "message" => "Transaction updated successfully!"
        }
      else
        {
          "type" => "transaction_error",
          "error" => updated_transaction[:error]
        }
      end
    end

    def process_transaction_deletion(result)
      return nil unless result["action"] == "delete_transaction"

      deleted_transaction = Fin::TransactionExecutor.new(@user).delete(result["transaction_id"])
      if deleted_transaction[:success]
        {
          "type" => "transaction_deleted",
          "data" => deleted_transaction,
          "message" => "Transaction deleted successfully!"
        }
      else
        {
          "type" => "transaction_error",
          "error" => deleted_transaction[:error]
        }
      end
    end

    def process_transaction_categorization(result)
      return nil unless result["action"] == "categorize_transactions"

      categorized = Fin::TransactionExecutor.new(@user).categorize_bulk
      {
        "type" => "transactions_categorized",
        "data" => categorized,
        "message" => "Started categorizing transactions in the background!"
      }
    end

    def process_stripe_connection(result)
      return nil unless result["action"] == "connect_stripe"

      { "type" => "connect_stripe", "data" => result }
    end

    def process_invoices_result(result)
      # If the result already has invoices, use them
      if result["invoices"].present?
        invoices = result["invoices"]
      else
        # Otherwise, fetch invoices based on filters
        filters = result["filters"] || {}
        invoices = Fin::InvoiceManager.new(@user).fetch_invoices(filters)
        invoices = Fin::InvoiceManager.new(@user).format_for_display(invoices)
      end

      return nil unless invoices.any?

      log_info "Found #{invoices.length} invoices"

      {
        "type" => "show_invoices",
        "data" => { "invoices" => invoices }
      }
    end

    def process_invoice_creation(result)
      return nil unless result["action"] == "create_invoice"

      created_invoice = Fin::InvoiceManager.new(@user).create(result["invoice"])
      if created_invoice[:success]
        invoice_id = created_invoice[:invoice][:id]
        {
          "type" => "invoice_created",
          "data" => created_invoice,
          "message" => "Invoice created successfully!",
          "invoice_id" => invoice_id
        }
      else
        {
          "type" => "invoice_error",
          "error" => created_invoice[:error]
        }
      end
    end

    def process_invoice_send(result)
      return nil unless result["action"] == "send_invoice"

      log_info "Processing send invoice action for invoice ID: #{result['invoice_id']}"

      # Find and send the invoice
      invoice = @user.invoices.find_by(id: result["invoice_id"])

      unless invoice
        log_error "Invoice not found: #{result['invoice_id']}"
        return {
          "type" => "invoice_error",
          "error" => "Invoice not found. Please check the invoice ID."
        }
      end

      sent_result = Fin::InvoiceManager.new(@user).send(:send_invoice, result["invoice_id"])

      if sent_result[:success]
        {
          "type" => "invoice_sent",
          "data" => sent_result,
          "message" => sent_result[:message],
          "invoice_url" => sent_result[:stripe_invoice_url]
        }
      else
        {
          "type" => "invoice_error",
          "error" => sent_result[:error]
        }
      end
    end

    def process_reminder_result(result)
      return nil unless result["action"] == "send_invoice_reminder"

      reminder_result = Fin::InvoiceManager.new(@user).send_reminder(result["invoice_id"])
      {
        "type" => "reminder_sent",
        "data" => reminder_result,
        "message" => reminder_result[:message]
      }
    end

    def process_invoice_payment(result)
      return nil unless result["action"] == "mark_invoice_paid"

      log_info "Marking invoice #{result['invoice_id']} as paid"

      paid_result = Fin::InvoiceManager.new(@user).mark_paid(result["invoice_id"])

      if paid_result[:success]
        {
          "type" => "invoice_marked_paid",
          "data" => paid_result,
          "message" => paid_result[:message]
        }
      else
        {
          "type" => "invoice_error",
          "error" => paid_result[:error]
        }
      end
    end

    def process_stripe_connect_setup(result)
      return nil unless result["action"] == "setup_stripe_connect"

      connect_status = Fin::StripeConnectManager.new(@user).status

      if connect_status[:connected]
        {
          "type" => "stripe_connect_already_setup",
          "data" => connect_status,
          "message" => "Your Stripe Connect account is already set up and ready to accept payments!"
        }
      else
        {
          "type" => "setup_stripe_connect",
          "data" => result.merge(connect_status)
        }
      end
    end

    def process_stripe_connect_status(result)
      connect_status = Fin::StripeConnectManager.new(@user).status
      {
        "type" => "show_stripe_connect_status",
        "data" => connect_status
      }
    end

    def process_dashboard_link(result)
      return nil unless result.present? && result["action"] == "create_stripe_connect_dashboard_link"

      log_info "Processing dashboard link result: #{result.inspect}"

      dashboard_result = Fin::StripeConnectManager.new(@user).create_dashboard_link

      if dashboard_result.present? && dashboard_result[:success]
        {
          "type" => "open_stripe_dashboard",
          "data" => dashboard_result,
          "message" => dashboard_result[:message] || "Opening your Stripe dashboard..."
        }
      else
        # Handle error scenarios gracefully
        error_message = dashboard_result&.dig(:error) || "Failed to create dashboard link"
        action_needed = dashboard_result&.dig(:action_needed)

        case action_needed
        when "restart_setup"
          {
            "type" => "stripe_connect_setup_needed",
            "error" => error_message,
            "message" => "You need to set up Stripe Connect first. Would you like me to start the setup process?"
          }
        else
          {
            "type" => "stripe_connect_error",
            "error" => error_message,
            "message" => "I wasn't able to open your Stripe dashboard right now. #{error_message}"
          }
        end
      end
    rescue StandardError => e
      log_error "Error in process_dashboard_link: #{e.message}"
      {
        "type" => "stripe_connect_error",
        "error" => e.message,
        "message" => "There was an error accessing your Stripe dashboard. Please try again."
      }
    end

    def process_plaid_connection(result)
      return nil unless result["action"] == "initiate_plaid_connection"

      {
        "type" => "initiate_plaid_connection",
        "action" => "initiate_plaid_connection",
        "data" => result,
        "user_id" => result["user_id"]
      }
    end

    def format_transactions_for_display(transactions)
      transactions.map do |transaction|
        {
          id: transaction["id"] || transaction[:id],
          amount: transaction["amount"].to_f,
          description: transaction["description"],
          date: transaction["date"],
          category: transaction["category"] || "Uncategorized",
          account_name: transaction["account"] || transaction["account_name"],
          recurring: transaction["recurring"] || false,
          editable: !transaction["plaid_transaction_id"].present?,
          plaid_synced: transaction["plaid_transaction_id"].present?,
          ai_categorized: transaction["ai_categorized"] || false,
          created_at: transaction["created_at"]
        }
      end
    end

    def calculate_summary_from_transactions(transactions)
      total_income = transactions.select { |t| t["amount"].to_f > 0 }.sum { |t| t["amount"].to_f }
      total_expenses = transactions.select { |t| t["amount"].to_f < 0 }.sum { |t| t["amount"].to_f.abs }

      category_breakdown = {}
      transactions.select { |t| t["amount"].to_f < 0 }.each do |t|
        category = t["category"] || "Uncategorized"
        category_breakdown[category] = (category_breakdown[category] || 0) + t["amount"].to_f.abs
      end

      {
        count: transactions.size,
        total_income: total_income,
        total_expenses: total_expenses,
        net_change: total_income - total_expenses,
        date_range: determine_date_range_from_transactions(transactions),
        category_breakdown: category_breakdown
      }
    end

    def determine_date_range_from_transactions(transactions)
      return "No transactions" if transactions.empty?

      dates = transactions.map { |t| Date.parse(t["date"]) }
      start_date = dates.min
      end_date = dates.max

      "#{start_date.strftime('%b %d, %Y')} to #{end_date.strftime('%b %d, %Y')}"
    end

    def enhance_with_links(response)
      return response unless response["actions"].present?

      response["actions"].each do |action|
        case action["type"]
        when "show_transactions"
          action["links"] ||= []
          action["links"] << { text: "View All Transactions", url: "/transactions" }
        when "show_forecast"
          action["links"] ||= []
          action["links"] << { text: "View Full Forecast", url: "/forecasts" }
        when "show_trends"
          action["links"] ||= []
          action["links"] << { text: "View All Insights", url: "/ai/insights" }
        when "show_budget"
          action["links"] ||= []
          action["links"] << { text: "Manage Budgets", url: "/budgets" }
        when "show_categories", "show_anomalies"
          action["links"] ||= []
          action["links"] << { text: "View All Transactions", url: "/transactions" }
        when "initiate_plaid_connection"
          log_info "Plaid connection action detected - UI should show Plaid link"
        when "transaction_created", "transaction_updated", "transaction_deleted"
          action["links"] ||= []
          action["links"] << { text: "View All Transactions", url: "/transactions" }
        when "open_stripe_dashboard"
          log_info "Stripe dashboard action detected - UI should open dashboard"
          # No additional links needed - dashboard will open in new window
        when "stripe_connect_error"
          log_info "Stripe Connect error action detected"
          # Add helpful links for error recovery
          action["links"] ||= []
          action["links"] << { text: "Stripe Connect Help", url: "/help/stripe-connect" }
        when "create_stripe_connect_dashboard_link"
          log_info "Direct Stripe dashboard link creation"
          # This might be a legacy action type - convert it
          action["type"] = "open_stripe_dashboard"
        else
          log_info "Processing action type: #{action['type']}"
        end
      end

      response
    end
  end
end
