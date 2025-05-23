# app/services/fin_service.rb - UPDATED VERSION
require "net/http"
require "uri"
require "json"

class FinService
  AI_SERVICE_URL = ENV["AI_SERVICE_URL"] || "http://localhost:5000"

  # Process a user query with Fin
  def self.process_query(user_id, query, conversation_history = nil)
    endpoint = "#{AI_SERVICE_URL}/fin/query"

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

    # If there was no error, and we have tool results, record them for learning
    if !response[:error] && response["tool_results"].present?
      record_tool_usage(user_id, query, response["tool_results"])
    end

    # Process actions to handle special cases like transaction management
    response = process_actions_for_ui(response, user_id)

    # Add UI links based on the response actions
    response = enhance_response_with_links(response)

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
    return response unless response["tool_results"].present?

    response["actions"] ||= []

    response["tool_results"].each do |tool_result|
      tool_name = tool_result["tool"]
      result = tool_result["result"]

      case tool_name
      when "get_transactions"
        # FIXED: Properly handle transaction display
        if result["transactions"].present?
          response["actions"] << {
            "type" => "show_transactions",
            "data" => {
              "transactions" => format_transactions_for_display(result["transactions"]),
              "summary" => result["summary"] || calculate_summary_from_transactions(result["transactions"])
            }
          }
        end

      when "get_user_accounts"
        if result["accounts"].present?
          response["actions"] << {
            "type" => "show_accounts",
            "data" => {
              "accounts" => result["accounts"]
            }
          }
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

    # Format for the AI service
    transactions.map do |t|
      {
        id: t.id,
        date: t.date.to_s,
        amount: t.amount.to_f,
        description: t.description,
        category: t.category&.name || "uncategorized",
        account: t.account.name,
        account_id: t.account.id,
        recurring: t.recurring,
        plaid_transaction_id: t.plaid_transaction_id
      }
    end
  end

  def self.fetch_user_context(user_id)
    user = User.find(user_id)

    # Get accounts
    accounts = user.accounts.map do |a|
      {
        name: a.name,
        type: a.account_type,
        balance: a.balance.to_f,
        id: a.id,
        institution: a.institution,
        plaid_account_id: a.plaid_account_id
      }
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

    # Return combined context
    {
      accounts: accounts,
      budgets: budgets,
      forecasts: forecasts,
      currency: user.currency || "USD",
      name: user.full_name
    }
  end

  def self.make_request(endpoint, payload)
    uri = URI.parse(endpoint)
    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
    request.body = payload.to_json

    begin
      response = http.request(request)

      if response.code.to_i == 200
        JSON.parse(response.body)
      else
        { error: "API request failed with status: #{response.code}: #{response.body}" }
      end
    rescue StandardError => e
      { error: "Failed to connect to AI service: #{e.message}" }
    end
  end
end
