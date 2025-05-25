class FinService
  include Rails.application.routes.url_helpers

  def self.process_query(user_id, query, conversation_history = nil)
    new(user_id).process_query(query, conversation_history)
  end

  def initialize(user_id)
    @user = User.find(user_id)
    @ai_client = Fin::AiClient.new
    @data_fetcher = Fin::DataFetcher.new(@user)
    @action_processor = Fin::ActionProcessor.new(@user)
    @learning_tracker = Fin::LearningTracker.new(@user)
  end

  def process_query(query, conversation_history = nil)
    log_info "🎯 Processing query for user #{@user.id}: #{query}"

    # Fetch required data
    transactions = @data_fetcher.fetch_transactions
    user_context = @data_fetcher.fetch_user_context

    # Call AI service
    response = @ai_client.query(
      user_id: @user.id,
      query: query,
      conversation_history: conversation_history,
      transactions: transactions,
      user_context: user_context
    )

    # Handle errors
    return response if response.key?(:error)

    # Record tool usage for learning
    if response["tool_results"].present?
      @learning_tracker.record_tool_usage(query, response["tool_results"])
    end

    # Process actions for UI
    processed_response = @action_processor.process_ai_response(response)

    log_info "✅ Query processed successfully"
    processed_response

  rescue StandardError => e
    Rails.logger.error "❌ [FinService] Error processing query: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { error: "Failed to process query: #{e.message}" }
  end

  private

  def log_info(message)
    Rails.logger.info "[FinService] #{message}"
  end
end
