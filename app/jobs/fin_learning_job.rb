class FinLearningJob < ApplicationJob
  queue_as :low_priority

  def perform
    Rails.logger.info "Starting Fin learning process..."

    # 1. Collect feedback statistics
    analyze_feedback_statistics

    # 2. Prepare learning dataset
    learning_dataset = prepare_learning_dataset

    # 3. Send learning dataset to the AI service for analysis and learning
    if learning_dataset.present?
      send_learning_dataset(learning_dataset)
    end

    Rails.logger.info "Fin learning process completed."
  end


  private

  def analyze_feedback_statistics
    # Calculate overall feedback metrics (just for logging and metrics)
    total_messages = FinMessage.assistant_messages.count
    feedback_messages = FinMessage.assistant_messages.with_feedback.count
    feedback_rate = feedback_messages.to_f / total_messages

    helpful_messages = FinMessage.assistant_messages.helpful.count
    helpfulness_rate = helpful_messages.to_f / feedback_messages

    Rails.logger.info "Feedback statistics:"
    Rails.logger.info "- Total assistant messages: #{total_messages}"
    Rails.logger.info "- Messages with feedback: #{feedback_messages} (#{(feedback_rate * 100).round(2)}%)"
    Rails.logger.info "- Helpful messages: #{helpful_messages} (#{(helpfulness_rate * 100).round(2)}%)"

    # Calculate tool usage statistics
    tools_used = FinMessage.where.not(tools_used: nil).sum { |m| m.tools_used.size }
    tools_success = FinMessage.where.not(tools_used: nil).sum do |m|
      m.tools_used.count { |t| t["success"] }
    end
    tools_success_rate = tools_success.to_f / [ tools_used, 1 ].max # Avoid div by zero

    Rails.logger.info "Tool usage statistics:"
    Rails.logger.info "- Total tool usages: #{tools_used}"
    Rails.logger.info "- Successful tool usages: #{tools_success} (#{(tools_success_rate * 100).round(2)}%)"

    # Record these metrics for tracking over time
    FinLearningMetric.create(
      total_messages: total_messages,
      feedback_messages: feedback_messages,
      helpful_messages: helpful_messages,
      tools_used: tools_used,
      tools_success: tools_success
    )
  end

  def prepare_learning_dataset
    # Identify conversations with different feedback characteristics
    helpful_conversations = FinConversation.joins(:fin_messages)
                                           .where(fin_messages: { was_helpful: true, feedback_rating: 4..5 })
                                           .distinct

    unhelpful_conversations = FinConversation.joins(:fin_messages)
                                             .where(fin_messages: { was_helpful: false, feedback_rating: 1..2 })
                                             .distinct

    # Format dataset for the Python service
    dataset = {
      helpful_conversations: format_conversations(helpful_conversations),
      unhelpful_conversations: format_conversations(unhelpful_conversations),
      tool_usage: collect_tool_usage_data
    }

    Rails.logger.info "Prepared learning dataset with #{dataset[:helpful_conversations].size} helpful and #{dataset[:unhelpful_conversations].size} unhelpful conversations"

    dataset
  end

  def format_conversations(conversations)
    conversations.map do |conversation|
      messages = conversation.fin_messages.order(created_at: :asc)

      # Format messages with all metadata needed for learning
      {
        id: conversation.id,
        messages: messages.map do |m|
          {
            role: m.role,
            content: m.content,
            feedback_rating: m.feedback_rating,
            was_helpful: m.was_helpful,
            tools_used: m.tools_used,
            led_to_action: m.led_to_action,
            financial_decision_made: m.financial_decision_made,
            decision_amount: m.decision_amount,
            created_at: m.created_at.to_s
          }
        end,
        user_id: conversation.user_id,
        created_at: conversation.created_at.to_s,
        title: conversation.title
      }
    end
  end

  def collect_tool_usage_data
    # Collect detailed data about tool usage and success rates
    tools_data = {}

    # Find all messages with tools used
    messages_with_tools = FinMessage.where.not(tools_used: nil)

    messages_with_tools.each do |message|
      message.tools_used.each do |tool|
        tool_name = tool["name"]
        success = tool["success"] || false
        query_context = tool["query_context"]
        parameters = tool["parameters"]

        # Initialize tool data if not exists
        tools_data[tool_name] ||= {
          total: 0,
          success: 0,
          contexts: [],
          parameters: []
        }

        # Update counters
        tools_data[tool_name][:total] += 1
        tools_data[tool_name][:success] += 1 if success

        # Store context samples (up to 10)
        if query_context.present? && tools_data[tool_name][:contexts].size < 10
          tools_data[tool_name][:contexts] << query_context
        end

        # Store parameter samples (up to 10)
        if parameters.present? && tools_data[tool_name][:parameters].size < 10
          tools_data[tool_name][:parameters] << parameters
        end
      end
    end

    tools_data
  end

  def send_learning_dataset(dataset)
    endpoint = "#{ENV['AI_SERVICE_URL']}/fin/learn"

    payload = {
      dataset: dataset
    }

    begin
      uri = URI.parse(endpoint)
      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
      request.body = payload.to_json

      response = http.request(request)

      if response.code.to_i == 200
        result = JSON.parse(response.body)
        Rails.logger.info "Learning dataset sent successfully. Processing results: #{result.inspect}"
      else
        Rails.logger.error "Failed to send learning dataset: #{response.code}: #{response.body}"
      end
    rescue StandardError => e
      Rails.logger.error "Error sending learning dataset: #{e.message}"
    end
  end
end
