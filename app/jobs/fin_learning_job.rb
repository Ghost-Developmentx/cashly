class FinLearningJob < ApplicationJob
  queue_as :low_priority

  def perform
    Rails.logger.info "Starting Fin learning process..."

    # 1. Analyze feedback statistics
    analyze_feedback_statistics

    # 2. Identify successful patterns
    success_patterns = identify_success_patterns

    # 3. Identify failure patterns
    failure_patterns = identify_failure_patterns

    # 4. Prepare learning dataset
    learning_dataset = prepare_learning_dataset

    # 5. Send learning dataset to the AI service for fine-tuning
    if learning_dataset.present?
      send_learning_dataset(learning_dataset)
    end

    Rails.logger.info "Fin learning process completed."
  end

  private

  def analyze_feedback_statistics
    # Calculate overall feedback metrics
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
    tools_success = FinMessage.where(tool_success: true).count
    tools_success_rate = tools_success.to_f / tools_used

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

  def identify_success_patterns
    # Find the most helpful conversations
    helpful_messages = FinMessage.assistant_messages.where(feedback_rating: 4..5, was_helpful: true)

    # Analyze the preceding user messages to find patterns
    user_message_patterns = {}

    helpful_messages.each do |message|
      conversation = message.fin_conversation

      # Find the user message that preceded this assistant message
      preceding_messages = conversation.fin_messages
                                       .where("created_at < ?", message.created_at)
                                       .order(created_at: :desc)
                                       .limit(3)

      user_message = preceding_messages.find { |m| m.role == "user" }
      next unless user_message

      # Extract key phrases or patterns from the user message
      # In a real implementation, you'd use NLP here
      simple_patterns = extract_simple_patterns(user_message.content)

      # Record how often each pattern appears in helpful conversations
      simple_patterns.each do |pattern|
        user_message_patterns[pattern] ||= 0
        user_message_patterns[pattern] += 1
      end
    end

    # Sort patterns by frequency
    top_patterns = user_message_patterns.sort_by { |_, count| -count }.take(10)

    Rails.logger.info "Top successful user query patterns:"
    top_patterns.each do |pattern, count|
      Rails.logger.info "- '#{pattern}': #{count} occurrences"
    end

    top_patterns
  end

  def identify_failure_patterns
    # Find unhelpful messages
    unhelpful_messages = FinMessage.assistant_messages.where(feedback_rating: 1..2, was_helpful: false)

    # Similar analysis as for success patterns
    user_message_patterns = {}

    unhelpful_messages.each do |message|
      conversation = message.fin_conversation

      preceding_messages = conversation.fin_messages
                                       .where("created_at < ?", message.created_at)
                                       .order(created_at: :desc)
                                       .limit(3)

      user_message = preceding_messages.find { |m| m.role == "user" }
      next unless user_message

      simple_patterns = extract_simple_patterns(user_message.content)

      simple_patterns.each do |pattern|
        user_message_patterns[pattern] ||= 0
        user_message_patterns[pattern] += 1
      end
    end

    top_patterns = user_message_patterns.sort_by { |_, count| -count }.take(10)

    Rails.logger.info "Top failure user query patterns:"
    top_patterns.each do |pattern, count|
      Rails.logger.info "- '#{pattern}': #{count} occurrences"
    end

    top_patterns
  end

  def prepare_learning_dataset
    # Find helpful conversations to use for fine-tuning
    helpful_conversations = FinConversation.joins(:fin_messages)
                                           .where(fin_messages: { was_helpful: true, feedback_rating: 4..5 })
                                           .distinct

    dataset = []

    helpful_conversations.each do |conversation|
      messages = conversation.fin_messages.order(created_at: :asc)

      # Need at least one exchange (user + assistant)
      next if messages.count < 2

      # Format as training examples
      conversation_data = {
        id: conversation.id,
        messages: messages.map { |m| { role: m.role, content: m.content } },
        tools_used: messages.flat_map { |m| m.tools_used.present? ? m.tools_used : [] },
        led_to_action: messages.any? { |m| m.led_to_action }
      }

      dataset << conversation_data
    end

    Rails.logger.info "Prepared learning dataset with #{dataset.size} conversations"

    dataset
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
        Rails.logger.info "Learning dataset sent successfully. Model update status: #{result['status']}"
      else
        Rails.logger.error "Failed to send learning dataset: #{response.code}: #{response.body}"
      end
    rescue StandardError => e
      Rails.logger.error "Error sending learning dataset: #{e.message}"
    end
  end

  def extract_simple_patterns(text)
    # In a real implementation, you'd use NLP or ML techniques
    # This is a very simple implementation for demonstration
    words = text.downcase.gsub(/[^\w\s]/, " ").split

    # Extract bigrams (pairs of adjacent words)
    bigrams = []
    words.each_cons(2) do |pair|
      bigrams << pair.join(" ")
    end

    # Extract key phrases (very simplified)
    key_phrases = []
    financial_terms = %w[budget spend expense income forecast saving investment]

    financial_terms.each do |term|
      if text.downcase.include?(term)
        start_idx = text.downcase.index(term)
        end_idx = [start_idx + 30, text.length].min
        key_phrases << text[start_idx...end_idx].strip
      end
    end

    # Combine words, bigrams and key phrases
    patterns = words + bigrams + key_phrases
    patterns.uniq
  end
end
