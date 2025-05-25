module Fin
  class LearningTracker < BaseService
    def initialize(user)
      @user = user
    end

    def record_tool_usage(query, tool_results)
      conversation = @user.fin_conversations.where(active: true).first
      message = conversation&.fin_messages&.where(role: "assistant")&.order(created_at: :desc)&.first

      return unless message

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
    rescue StandardError => e
      log_error "Failed to record tool usage: #{e.message}"
    end

    private

    def summarize_tool_result(result)
      return "error" if result.key?("error")

      if result.is_a?(Hash)
        if result.key?("forecast")
          "forecast with #{result['forecast'].size} days"
        elsif result.key?("insights")
          "#{result['insights'].size} insights"
        elsif result.key?("transactions")
          "#{result['transactions'].size} transactions"
        elsif result.key?("action")
          summarize_action_result(result)
        else
          "success"
        end
      elsif result.is_a?(Array)
        "array with #{result.size} items"
      else
        "success"
      end
    end

    def summarize_action_result(result)
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
    end
  end
end
