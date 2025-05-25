# app/services/fin_service.rb - UPDATED VERSION
require "net/http"
require "uri"
require "json"

class FinService
  AI_SERVICE_URL = ENV["AI_SERVICE_URL"] || "http://localhost:5000"

  # Process a user query with Fin
  def self.process_query(user_id, query, conversation_history = nil)
    endpoint = "#{AI_SERVICE_URL}/fin/conversations/query"

    # Get user's transactions
    transactions = fetch_user_transactions(user_id)

    # Get user context (accounts, budgets, etc.)
    user_context = fetch_user_context(user_id)

    payload = {
      user_id: user_id,
      query: query,
      transactions: transactions,
      conversation_history: conversation_history,
      user_context: user_context
    }

    response = make_request(endpoint, payload)

    Rails.logger.info "📥 [FinService] Raw response keys: #{response.keys}"
    Rails.logger.info "📥 [FinService] Actions count: #{response['actions']&.length || 0}"
    Rails.logger.info "📥 [FinService] Tool results count: #{response['tool_results']&.length || 0}"


    # If there was no error, and we have tool results, record them for learning
    if !response[:error] && response["tool_results"].present?
      record_tool_usage(user_id, query, response["tool_results"])
    end

    # Process actions to handle special cases like transaction management
    response = process_actions_for_ui(response, user_id)

    Rails.logger.info "🔄 [FinService] After UI processing - Actions: #{response['actions']&.length || 0}"
    response["actions"]&.each_with_index do |action, i|
      Rails.logger.info "🔄 [FinService] Action #{i}: type=#{action['type']}, has_data=#{action['data'].present?}"
    end

    # Add UI links based on the response actions
    response = enhance_response_with_links(response)

    Rails.logger.info "✅ [FinService] Final response - Actions: #{response['actions']&.length || 0}"

    response
  end

  def self.record_tool_usage(user_id, query, tool_results)
    user = User.find(user_id)
    conversation = user.fin_conversations.where(active: true).first
    message = conversation&.fin_messages&.where(role: "assistant")&.order(created_at: :desc)&.first

    if message
      tools_used = tool_results.map do |tool_result|
        {
          name: tool_result["tool"],
          success: !tool_result["result"].key?("error"),
          timestamp: Time.current.to_s,
          query_context: query,
          parameters: tool_result["parameters"],
          result_summary: summarize_tool_result(tool_result["result"])
        }
      end

      message.update(tools_used: tools_used)
    end
  end

  def self.summarize_tool_result(result)
    return "error" if result.key?("error")

    if result.is_a?(Hash)
      if result.key?("forecast")
        "forecast with #{result['forecast'].size} days"
      elsif result.key?("insights")
        "#{result['insights'].size} insights"
      elsif result.key?("transactions")
        "#{result['transactions'].size} transactions"
      elsif result.key?("action")
        case result["action"]
        when "create_transaction"
          "create transaction: #{result['transaction']['description']}"
        when "update_transaction"
          "update transaction #{result['transaction_id']}"
        when "delete_transaction"
          "delete transaction #{result['transaction_id']}"
        when "initiate_plaid_connection"
          "initiate plaid connection"
        else
          result["action"]
        end
      else
        "success"
      end
    elsif result.is_a?(Array)
      "array with #{result.size} items"
    else
      "success"
    end
  end

  # Process actions from AI service to ensure they're properly formatted for UI
  def self.process_actions_for_ui(response, user_id)
    Rails.logger.info "🔧 [FinService] Processing actions for UI"
    Rails.logger.info "🔧 [FinService] Input - tool_results: #{response['tool_results']&.length || 0}, actions: #{response['actions']&.length || 0}"


    return response unless response["tool_results"].present?

    response["actions"] ||= []

    response["tool_results"].each do |tool_result|
      tool_name = tool_result["tool"]
      result = tool_result["result"]

      Rails.logger.info "🔧 [FinService] Processing tool: #{tool_name}"
      Rails.logger.info "🔧 [FinService] Result keys: #{result.keys}" if result.is_a?(Hash)


      case tool_name
      when "get_transactions"
        if result["transactions"].present?
          Rails.logger.info "🔧 [FinService] Found #{result['transactions'].length} transactions"
          action = {
            "type" => "show_transactions",
            "data" => {
              "transactions" => format_transactions_for_display(result["transactions"]),
              "summary" => result["summary"] || calculate_summary_from_transactions(result["transactions"])
            }
          }
          response["actions"] << action
          Rails.logger.info "✅ [FinService] Added show_transactions action"
        end

      when "get_user_accounts"
        if result["accounts"].present?
          Rails.logger.info "🔧 [FinService] Found #{result['accounts'].length} accounts"
          action = {
            "type" => "show_accounts",
            "data" => {
              "accounts" => result["accounts"]
            }
          }
          response["actions"] << action
          Rails.logger.info "✅ [FinService] Added show_accounts action"
        end

      when "create_transaction"
        if result["action"] == "create_transaction"
          # Execute the transaction creation
          created_transaction = execute_create_transaction(user_id, result["transaction"])
          if created_transaction[:success]
            response["actions"] << {
              "type" => "transaction_created",
              "data" => created_transaction,
              "message" => "Transaction created successfully!"
            }
          else
            response["actions"] << {
              "type" => "transaction_error",
              "error" => created_transaction[:error]
            }
          end
        end

      when "update_transaction"
        if result["action"] == "update_transaction"
          updated_transaction = execute_update_transaction(user_id, result["transaction_id"], result["updates"])
          if updated_transaction[:success]
            response["actions"] << {
              "type" => "transaction_updated",
              "data" => updated_transaction,
              "message" => "Transaction updated successfully!"
            }
          else
            response["actions"] << {
              "type" => "transaction_error",
              "error" => updated_transaction[:error]
            }
          end
        end

      when "delete_transaction"
        if result["action"] == "delete_transaction"
          deleted_transaction = execute_delete_transaction(user_id, result["transaction_id"])
          if deleted_transaction[:success]
            response["actions"] << {
              "type" => "transaction_deleted",
              "data" => deleted_transaction,
              "message" => "Transaction deleted successfully!"
            }
          else
            response["actions"] << {
              "type" => "transaction_error",
              "error" => deleted_transaction[:error]
            }
          end
        end

      when "categorize_transactions"
        if result["action"] == "categorize_transactions"
          categorized = execute_categorize_transactions(user_id)
          response["actions"] << {
            "type" => "transactions_categorized",
            "data" => categorized,
            "message" => "Started categorizing transactions in the background!"
          }
        end

      when "connect_stripe"
        if result["action"] == "connect_stripe"
          response["actions"] << {
            "type" => "connect_stripe",
            "data" => result
          }
        end

      when "get_invoices"
        # Execute the invoice fetch
        invoices = fetch_user_invoices(user_id, result["filters"] || {})
        if invoices.any?
          response["actions"] << {
            "type" => "show_invoices",
            "data" => {
              "invoices" => format_invoices_for_display(invoices)
            }
          }
        end

      when "create_invoice"
        if result["action"] == "create_invoice"
          created_invoice = execute_create_invoice(user_id, result["invoice"])
          if created_invoice[:success]
            response["actions"] << {
              "type" => "invoice_created",
              "data" => created_invoice,
              "message" => "Invoice created successfully!"
            }
          else
            response["actions"] << {
              "type" => "invoice_error",
              "error" => created_invoice[:error]
            }
          end
        end

      when "send_invoice_reminder"
        if result["action"] == "send_invoice_reminder"
          reminder_result = execute_send_reminder(user_id, result["invoice_id"])
          response["actions"] << {
            "type" => "reminder_sent",
            "data" => reminder_result,
            "message" => reminder_result[:message]
          }
        end

      when "mark_invoice_paid"
        if result["action"] == "mark_invoice_paid"
          paid_result = execute_mark_invoice_paid(user_id, result["invoice_id"])
          response["actions"] << {
            "type" => "invoice_marked_paid",
            "data" => paid_result,
            "message" => paid_result[:message]
          }
        end

      when "setup_stripe_connect"
        if result["action"] == "setup_stripe_connect"
          connect_status = check_stripe_connect_status(user_id)

          if connect_status[:connected]
            response["actions"] << {
              "type" => "stripe_connect_already_setup",
              "data" => connect_status,
              "message" => "Your Stripe Connect account is already set up and ready to accept payments!"
            }
          else
            response["actions"] << {
              "type" => "setup_stripe_connect",
              "data" => result.merge(connect_status)
            }
          end
        end

      when "check_stripe_connect_status"
        connect_status = check_stripe_connect_status(user_id)
        response["actions"] << {
          "type" => "show_stripe_connect_status",
          "data" => connect_status
        }

      when "create_stripe_connect_dashboard_link"
        if result["action"] == "create_stripe_connect_dashboard_link"
          dashboard_result = execute_create_dashboard_link(user_id)
          if dashboard_result[:success]
            response["actions"] << {
              "type" => "open_stripe_dashboard",
              "data" => dashboard_result,
              "message" => "Opening your Stripe dashboard..."
            }
          else
            response["actions"] << {
              "type" => "stripe_connect_error",
              "error" => dashboard_result[:error]
            }
          end
        end

      when "initiate_plaid_connection"
        if result["action"] == "initiate_plaid_connection"
          response["actions"] << {
            "type" => "initiate_plaid_connection",
            "action" => "initiate_plaid_connection",
            "data" => result,
            "user_id" => result["user_id"]
          }
        end
      end
    end
    Rails.logger.info "🔧 [FinService] Output - actions: #{response['actions'].length}"
    response
  end

  def self.format_transactions_for_display(transactions)
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

  def self.fetch_user_invoices(user_id, filters = {})
    user = User.find(user_id)
    invoices = user.invoices

    # Apply filters
    invoices = invoices.where(status: filters["status"]) if filters["status"].present?

    if filters["days"].present?
      start_date = filters["days"].to_i.days.ago
      invoices = invoices.where("created_at >= ?", start_date)
    end

    if filters["client_name"].present?
      invoices = invoices.where("client_name ILIKE ?", "%#{filters['client_name']}%")
    end

    invoices.order(created_at: :desc).limit(20)
  end

  def self.format_invoices_for_display(invoices)
    invoices.map do |invoice|
      {
        id: invoice.id,
        client_name: invoice.client_name,
        client_email: invoice.client_email,
        amount: invoice.amount.to_f,
        status: invoice.status,
        issue_date: invoice.issue_date.strftime("%Y-%m-%d"),
        due_date: invoice.due_date.strftime("%Y-%m-%d"),
        invoice_number: invoice.generate_invoice_number,
        description: invoice.description,
        stripe_invoice_id: invoice.stripe_invoice_id
      }
    end
  end

  def self.execute_create_invoice(user_id, invoice_data)
    user = User.find(user_id)
    connect_account = user.stripe_connect_account

    # Create the Cashly invoice first
    invoice = user.invoices.new(
      client_name: invoice_data["client_name"],
      client_email: invoice_data["client_email"],
      amount: invoice_data["amount"],
      description: invoice_data["description"],
      issue_date: Date.current,
      due_date: invoice_data["due_date"] || 30.days.from_now,
      status: "draft",
      currency: user.currency || "USD"
    )

    if invoice.save
      # If a user has Stripe Connect, create the Stripe invoice too
      if connect_account&.can_accept_payments?
        service = StripeConnectService.new(user)
        stripe_result = service.create_invoice_with_fee({
                                                          amount: invoice.amount,
                                                          client_email: invoice.client_email,
                                                          client_name: invoice.client_name,
                                                          description: invoice.description,
                                                          currency: invoice.currency,
                                                          cashly_invoice_id: invoice.id
                                                        })

        if stripe_result[:success]
          invoice.update!(
            stripe_invoice_id: stripe_result[:stripe_invoice].id,
            status: "pending"
          )

          {
            success: true,
            invoice: format_invoice_for_response(invoice),
            platform_fee: stripe_result[:platform_fee],
            message: "Invoice created with Stripe Connect! Platform fee: $#{stripe_result[:platform_fee]}"
          }
        else
          {
            success: true,
            invoice: format_invoice_for_response(invoice),
            warning: "Invoice created but Stripe integration failed: #{stripe_result[:error]}"
          }
        end
      else
        {
          success: true,
          invoice: format_invoice_for_response(invoice),
          message: "Invoice created successfully. Set up Stripe Connect to accept payments."
        }
      end
    else
      { success: false, error: invoice.errors.full_messages.join(", ") }
    end
  end

  def self.execute_send_reminder(user_id, invoice_id)
    user = User.find(user_id)
    invoice = user.invoices.find_by(id: invoice_id)

    return { success: false, error: "Invoice not found" } unless invoice
    return { success: false, error: "Can only send reminders for pending invoices" } unless invoice.status == "pending"

    invoice.send_reminder

    {
      success: true,
      invoice_id: invoice.id,
      message: "Payment reminder sent to #{invoice.client_name}"
    }
  end

  def self.execute_mark_invoice_paid(user_id, invoice_id)
    user = User.find(user_id)
    invoice = user.invoices.find_by(id: invoice_id)

    return { success: false, error: "Invoice not found" } unless invoice

    invoice.mark_as_paid

    {
      success: true,
      invoice: format_invoice_for_response(invoice),
      message: "Invoice marked as paid"
    }
  end

  def self.format_invoice_for_response(invoice)
    {
      id: invoice.id,
      client_name: invoice.client_name,
      client_email: invoice.client_email,
      amount: invoice.amount.to_f,
      status: invoice.status,
      issue_date: invoice.issue_date.strftime("%Y-%m-%d"),
      due_date: invoice.due_date.strftime("%Y-%m-%d"),
      invoice_number: invoice.generate_invoice_number,
      description: invoice.description
    }
  end

  def self.calculate_summary_from_transactions(transactions)
    total_income = transactions.select { |t| t["amount"].to_f > 0 }.sum { |t| t["amount"].to_f }
    total_expenses = transactions.select { |t| t["amount"].to_f < 0 }.sum { |t| t["amount"].to_f.abs }

    # Category breakdown
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

  def self.determine_date_range_from_transactions(transactions)
    return "No transactions" if transactions.empty?

    dates = transactions.map { |t| Date.parse(t["date"]) }
    start_date = dates.min
    end_date = dates.max

    "#{start_date.strftime('%b %d, %Y')} to #{end_date.strftime('%b %d, %Y')}"
  end

  # Execute transaction management actions
  def self.execute_create_transaction(user_id, transaction_data)
    user = User.find(user_id)

    # Find an account
    account = if transaction_data["account_id"]
                user.accounts.find_by(id: transaction_data["account_id"])
    elsif transaction_data["account_name"]
                user.accounts.where("name ILIKE ?", "%#{transaction_data['account_name']}%").first
    else
                user.accounts.first # Default to the first account
    end

    return { success: false, error: "Account not found" } unless account

    # Create transaction
    transaction = account.transactions.new(
      amount: transaction_data["amount"],
      description: transaction_data["description"],
      date: transaction_data["date"] || Date.current,
      recurring: transaction_data["recurring"] || false
    )

    # Handle category
    if transaction_data["category"]
      category = Category.find_or_create_by(name: transaction_data["category"])
      transaction.category = category
    end

    if transaction.save
      {
        success: true,
        transaction: format_transaction_for_response(transaction),
        message: "Transaction created successfully"
      }
    else
      { success: false, error: transaction.errors.full_messages.join(", ") }
    end
  end

  def self.execute_update_transaction(user_id, transaction_id, updates)
    user = User.find(user_id)
    transaction = user.transactions.find_by(id: transaction_id)

    return { success: false, error: "Transaction not found" } unless transaction
    return { success: false, error: "Cannot edit bank-synced transactions" } if transaction.plaid_transaction_id.present?

    # Handle category update
    if updates["category"]
      category = Category.find_or_create_by(name: updates["category"])
      updates["category_id"] = category.id
      updates.delete("category")
    end

    if transaction.update(updates)
      {
        success: true,
        transaction: format_transaction_for_response(transaction),
        message: "Transaction updated successfully"
      }
    else
      { success: false, error: transaction.errors.full_messages.join(", ") }
    end
  end

  def self.execute_delete_transaction(user_id, transaction_id)
    user = User.find(user_id)
    transaction = user.transactions.find_by(id: transaction_id)

    return { success: false, error: "Transaction not found" } unless transaction
    return { success: false, error: "Cannot delete bank-synced transactions" } if transaction.plaid_transaction_id.present?

    transaction_info = {
      description: transaction.description,
      amount: transaction.amount,
      account: transaction.account.name
    }

    if transaction.destroy
      {
        success: true,
        deleted_transaction: transaction_info,
        message: "Transaction deleted successfully"
      }
    else
      { success: false, error: "Failed to delete transaction" }
    end
  end

  def self.execute_categorize_transactions(user_id)
    user = User.find(user_id)
    uncategorized_transactions = user.transactions.where(category_id: nil).limit(50)

    if uncategorized_transactions.any?
      CategorizeTransactionsJob.perform_later(user_id, uncategorized_transactions.pluck(:id))
      {
        success: true,
        count: uncategorized_transactions.count,
        message: "Categorizing #{uncategorized_transactions.count} transactions in the background"
      }
    else
      { success: true, count: 0, message: "All transactions are already categorized!" }
    end
  end

  def self.format_transaction_for_response(transaction)
    {
      id: transaction.id,
      amount: transaction.amount.to_f,
      description: transaction.description,
      date: transaction.date.strftime("%Y-%m-%d"),
      category: transaction.category&.name || "Uncategorized",
      account: transaction.account.name,
      recurring: transaction.recurring || false,
      editable: transaction.plaid_transaction_id.blank?
    }
  end

  # Add useful UI links based on the actions detected by the AI service
  def self.enhance_response_with_links(response)
    return response unless response["actions"].present?

    response["actions"].each do |action|
      case action["type"]
      when "show_transactions"
        action["links"] ||= []
        action["links"] << {
          text: "View All Transactions",
          url: "/transactions"
        }
      when "show_forecast"
        action["links"] ||= []
        action["links"] << {
          text: "View Full Forecast",
          url: "/forecasts"
        }
      when "show_trends"
        action["links"] ||= []
        action["links"] << {
          text: "View All Insights",
          url: "/ai/insights"
        }
      when "show_budget"
        action["links"] ||= []
        action["links"] << {
          text: "Manage Budgets",
          url: "/budgets"
        }
      when "show_categories", "show_anomalies"
        action["links"] ||= []
        action["links"] << {
          text: "View All Transactions",
          url: "/transactions"
        }
      when "initiate_plaid_connection"
        # No additional links needed - this triggers the Plaid modal
        Rails.logger.info "Plaid connection action detected - UI should show Plaid link"
      when "transaction_created", "transaction_updated", "transaction_deleted"
        action["links"] ||= []
        action["links"] << {
          text: "View All Transactions",
          url: "/transactions"
        }
      else
        Rails.logger.info "Unknown action type: #{action['type']}"
      end
    end

    response
  end

  private

  def self.fetch_user_transactions(user_id)
    user = User.find(user_id)

    # Get transactions from the last 6 months
    start_date = 6.months.ago.to_date

    transactions = user.transactions
                       .where("date >= ?", start_date)
                       .includes(:category, :account)
                       .order(date: :desc)

    Rails.logger.info "🔍 [FinService] User #{user_id} has #{transactions.count} transactions"
    Rails.logger.info "🔍 [FinService] Date range: #{start_date} to #{Date.current}"

    # Log the first few transactions for debugging
    transactions.limit(3).each_with_index do |t, i|
      Rails.logger.info "🔍 [FinService] Transaction #{i}: ID=#{t.id}, Date=#{t.date}, Account=#{t.account.name} (ID=#{t.account.id}), Amount=#{t.amount}"
    end

    # Format for the AI service - FIX THE DATE FORMAT HERE
    formatted_transactions = transactions.map do |t|
      {
        id: t.id,
        date: t.date.strftime("%Y-%m-%d"),  # ✅ FIXED: Use strftime instead of to_s
        amount: t.amount.to_f,
        description: t.description,
        category: t.category&.name || "uncategorized",
        account: t.account.name,
        account_id: t.account.id,
        recurring: t.recurring,
        plaid_transaction_id: t.plaid_transaction_id
      }
    end

    Rails.logger.info "🔍 [FinService] Formatted #{formatted_transactions.count} transactions for AI service"

    # Log first formatted transaction for debugging
    if formatted_transactions.any?
      first_txn = formatted_transactions.first
      Rails.logger.info "🔍 [FinService] First formatted transaction: #{first_txn}"
    end

    formatted_transactions
  end

  def self.check_stripe_connect_status(user_id)
    user = User.find(user_id)
    connect_account = user.stripe_connect_account

    if connect_account
      connect_account.sync_from_stripe!

      {
        connected: true,
        status: connect_account.status,
        charges_enabled: connect_account.charges_enabled,
        payouts_enabled: connect_account.payouts_enabled,
        details_submitted: connect_account.details_submitted,
        onboarding_complete: connect_account.onboarding_complete?,
        platform_fee_percentage: connect_account.platform_fee_percentage,
        can_accept_payments: connect_account.can_accept_payments?,
        requirements: connect_account.requirements
      }
    else
      {
        connected: false,
        status: "not_connected",
        charges_enabled: false,
        payouts_enabled: false,
        details_submitted: false,
        onboarding_complete: false,
        can_accept_payments: false
      }
    end
  end

  def self.execute_create_stripe_connect_account(user_id, account_params)
    user = User.find(user_id)

    # Check if a user already has a Connect account
    if user.stripe_connect_account.present?
      return {
        success: false,
        error: "You already have a Stripe Connect account set up"
      }
    end

    service = StripeConnectService.new(user)
    result = service.create_express_account(
      country: account_params["country"] || "US",
      business_type: account_params["business_type"] || "individual"
    )

    if result[:success]
      {
        success: true,
        onboarding_url: result[:onboarding_url],
        account_id: result[:account].stripe_account_id,
        message: "Stripe Connect account created! Complete your onboarding to start accepting payments."
      }
    else
      { success: false, error: result[:error] }
    end
  end

  def self.execute_create_dashboard_link(user_id)
    user = User.find(user_id)
    service = StripeConnectService.new(user)
    service.create_dashboard_link
  end


  def self.fetch_user_context(user_id)
    user = User.find(user_id)

    # Get accounts with debugging
    accounts_query = user.accounts
    Rails.logger.info "🔍 [FinService] User #{user_id} has #{accounts_query.count} accounts"

    accounts = accounts_query.map do |a|
      account_data = {
        name: a.name,
        type: a.account_type,
        balance: a.balance.to_f,
        id: a.id,
        institution: a.institution,
        plaid_account_id: a.plaid_account_id
      }
      Rails.logger.info "🔍 [FinService] Account: ID=#{account_data[:id]}, Name='#{account_data[:name]}'"
      account_data
    end

    # Get budgets
    budgets = user.budgets.includes(:category).map do |b|
      {
        category: b.category.name,
        amount: b.amount.to_f,
        id: b.id
      }
    end

    # Get recent forecasts
    forecasts = user.forecasts.order(created_at: :desc).limit(3).map do |f|
      {
        name: f.name,
        time_horizon: f.time_horizon,
        id: f.id,
        scenario_type: f.scenario_type
      }
    end

    # Get Stripe Connect status
    stripe_connect_status = user.stripe_connect_status

    # Get integrations
    integrations = user.integrations.active.map do |integration|
      {
        provider: integration.provider,
        status: integration.status,
        last_used: integration.last_used_at
      }
    end

    # Get invoice statistics for Stripe Connect context
    invoice_stats = calculate_invoice_stats(user)

    # Return combined context
    context = {
      accounts: accounts,
      budgets: budgets,
      forecasts: forecasts,
      stripe_connect: stripe_connect_status,
      integrations: integrations,
      invoice_stats: invoice_stats,
      currency: user.currency || "USD",
      name: user.full_name
    }

    Rails.logger.info "🔍 [FinService] User context: #{accounts.count} accounts, #{budgets.count} budgets, #{integrations.count} integrations"

    context
  end

  def self.calculate_invoice_stats(user)
    invoices = user.invoices

    {
      total_count: invoices.count,
      pending_count: invoices.where(status: "pending").count,
      pending_amount: invoices.where(status: "pending").sum(:amount).to_f,
      overdue_count: invoices.where("status = 'pending' AND due_date < ?", Date.current).count,
      paid_count: invoices.where(status: "paid").count,
      paid_amount: invoices.where(status: "paid").sum(:amount).to_f,
      draft_count: invoices.where(status: "draft").count
    }
  end

  def self.make_request(endpoint, payload)
    # Add debugging for the payload
    Rails.logger.info "🔍 [FinService] Making request to: #{endpoint}"
    Rails.logger.info "🔍 [FinService] Payload keys: #{payload.keys}"
    Rails.logger.info "🔍 [FinService] Payload transactions count: #{payload[:transactions]&.length || 0}"
    Rails.logger.info "🔍 [FinService] Payload user_context accounts count: #{payload[:user_context]&.dig(:accounts)&.length || 0}"

    # Log first transaction if available
    if payload[:transactions]&.any?
      first_txn = payload[:transactions].first
      Rails.logger.info "🔍 [FinService] First transaction in payload: #{first_txn}"
    end

    uri = URI.parse(endpoint)
    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
    request.body = payload.to_json

    # Log the request body size for debugging
    Rails.logger.info "🔍 [FinService] Request body size: #{request.body.length} characters"

    begin
      response = http.request(request)

      Rails.logger.info "🔍 [FinService] Response status: #{response.code}"

      if response.code.to_i == 200
        parsed_response = JSON.parse(response.body)
        Rails.logger.info "🔍 [FinService] Response keys: #{parsed_response.keys}"
        parsed_response
      else
        Rails.logger.error "🔍 [FinService] API request failed: #{response.code}: #{response.body}"
        { error: "API request failed with status: #{response.code}: #{response.body}" }
      end
    rescue StandardError => e
      Rails.logger.error "🔍 [FinService] Connection error: #{e.message}"
      { error: "Failed to connect to AI service: #{e.message}" }
    end
  end
end
