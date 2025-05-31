# app/services/fin_service.rb
class FinService
  attr_reader :user, :ai_client, :context_builder, :response_processor

  def initialize(user)
    @user = user
    @ai_client = Fin::AiClient.new
    @context_builder = Fin::ContextBuilder.new(user)
    @response_processor = Fin::ResponseProcessor.new(user)
  end

  def process_query(query, conversation_history = nil)
    Rails.logger.info "[FinService] Processing query: #{query}"
    Rails.logger.info "[FinService] Conversation history: #{conversation_history&.length || 0} messages"

    # Build context
    context = context_builder.build

    # Get active conversation ID if available
    active_conversation = user.fin_conversations.active.first
    conversation_id = active_conversation&.id

    # Add conversation ID to user context
    context[:user_context][:conversation_id] = "fin_conv_#{conversation_id}" if conversation_id
    context[:user_context][:fin_conversation_id] = conversation_id if conversation_id

    # Call AI with conversation history
    ai_response = ai_client.query(
      user_id: user.id,
      query: query,
      conversation_history: conversation_history,
      **context
    )

    # Process response (handles all tool results -> actions)
    response_processor.process(ai_response)

  rescue StandardError => e
    Rails.logger.error "[FinService] Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    { error: e.message }
  end
end
