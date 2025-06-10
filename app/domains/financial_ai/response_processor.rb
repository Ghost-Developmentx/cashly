module FinancialAI
  class ResponseProcessor
    def initialize(user)
      @user = user
      @processed_tools = Set.new
    end

    def process(ai_response)
      return ai_response.actions if ai_response.tool_results.blank?

      actions = []

      ai_response.tool_results.each do |tool_result|
        next if skip_tool?(tool_result)

        action = execute_tool(tool_result)
        actions << enhance_action(action) if action

        mark_as_processed(tool_result)
      end

      actions
    end

    private

    def skip_tool?(tool_result)
      tool_key = generate_tool_key(tool_result)
      @processed_tools.include?(tool_key)
    end

    def execute_tool(tool_result)
      Fin::ActionRegistry.execute(
        tool_result["tool"],
        @user,
        tool_result["result"],
        tool_result["parameters"]
      )
    rescue StandardError => e
      Rails.logger.error "[ResponseProcessor] Error executing #{tool_result['tool']}: #{e.message}"
      {
        type: "#{tool_result['tool']}_error",
        success: false,
        error: e.message
      }
    end

    def enhance_action(action)
      return action unless action.is_a?(Hash)

      # Add any additional links or metadata
      LinkEnhancer.new.enhance(action)
    end

    def mark_as_processed(tool_result)
      tool_key = generate_tool_key(tool_result)
      @processed_tools.add(tool_key)
    end

    def generate_tool_key(tool_result)
      tool_name = tool_result["tool"]
      params = tool_result["parameters"] || {}
      sorted_params = params.sort.to_h
      "#{tool_name}_#{sorted_params.to_json}"
    end
  end

  class LinkEnhancer
    LINK_MAPPINGS = {
      "get_transactions" => [ { text: "View All Transactions", url: "/transactions" } ],
      "show_forecast" => [ { text: "View Full Forecast", url: "/forecasts" } ],
      "show_invoices" => [ { text: "View All Invoices", url: "/invoices" } ],
      "invoice_create_success" => [ { text: "View Invoice", url: "/invoices" } ],
      "transaction_created" => [ { text: "View Transaction", url: "/transactions" } ]
    }.freeze

    def enhance(action)
      return action unless action["type"]

      if LINK_MAPPINGS[action["type"]]
        action["links"] ||= []
        action["links"].concat(LINK_MAPPINGS[action["type"]])
      end

      action
    end
  end
end
