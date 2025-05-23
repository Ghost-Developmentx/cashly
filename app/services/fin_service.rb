# app/services/fin_service.rb
# app/services/fin_service.rb
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
      # Find the message that was just saved
      user = User.find(user_id)
      conversation = user.fin_conversations.where(active: true).first
      message = conversation&.fin_messages&.where(role: "assistant")&.order(created_at: :desc)&.first

      if message
        # Record the tools that were used with more detailed context
        tools_used = response["tool_results"].map do |tool_result|
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

    # Process actions to handle special cases like Plaid connections
    response = process_actions_for_ui(response)

    # Add UI links based on the response actions
    response = enhance_response_with_links(response)

    response
  end

  def self.summarize_tool_result(result)
    return "error" if result.key?("error")

    # Create a summary based on the type of result
    if result.is_a?(Hash)
      if result.key?("forecast")
        "forecast with #{result['forecast'].size} days"
      elsif result.key?("insights")
        "#{result['insights'].size} insights"
      elsif result.key?("recommendations")
        "#{result['recommendations'].size} recommendations"
      elsif result.key?("action") && result["action"] == "initiate_plaid_connection"
        "initiate plaid connection"
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
  def self.process_actions_for_ui(response)
    return response unless response["tool_results"].present?

    # Ensure actions array exists
    response["actions"] ||= []

    # Check tool results for special actions that need UI handling
    response["tool_results"].each do |tool_result|
      tool_name = tool_result["tool"]
      result = tool_result["result"]

      # Handle initiate_plaid_connection specially
      if tool_name == "initiate_plaid_connection" && result["action"] == "initiate_plaid_connection"
        # Check if this action is already in the actions array
        plaid_action_exists = response["actions"].any? do |action|
          action["type"] == "initiate_plaid_connection" || action["action"] == "initiate_plaid_connection"
        end

        # If not, add it
        unless plaid_action_exists
          response["actions"] << {
            "type" => "initiate_plaid_connection",
            "action" => "initiate_plaid_connection",
            "data" => result,
            "user_id" => result["user_id"]
          }
        end
      end

      # Handle get_user_accounts especially if it shows 0 accounts and the user wants to connect
      if tool_name == "get_user_accounts" && result["account_count"] == 0
        # This might be followed by an initiate_plaid_connection, so we'll let that handle it
      end
    end

    response
  end

  # Add useful UI links based on the actions detected by the AI service
  def self.enhance_response_with_links(response)
    # Only enhance if we have actions from the AI service
    return response unless response["actions"].present?

    # For each action, add appropriate UI links if needed
    response["actions"].each do |action|
      case action["type"]
      when "show_forecast"
        # Add a link to the relevant forecast
        action["links"] ||= []
        action["links"] << {
          text: "View Full Forecast",
          url: "/forecasts"
        }
      when "show_trends"
        # Add a link to the insights page
        action["links"] ||= []
        action["links"] << {
          text: "View All Insights",
          url: "/ai/insights"
        }
      when "show_budget"
        # Add a link to the budget page
        action["links"] ||= []
        action["links"] << {
          text: "Manage Budgets",
          url: "/budgets"
        }
      when "show_categories", "show_anomalies"
        # Add a link to transactions
        action["links"] ||= []
        action["links"] << {
          text: "View All Transactions",
          url: "/transactions"
        }
      when "initiate_plaid_connection"
        # No additional links needed - this triggers the Plaid modal
        Rails.logger.info "Plaid connection action detected - UI should show Plaid link"
      else
        # Log unknown action types for debugging
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
        recurring: t.recurring
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
