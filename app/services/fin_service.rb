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

    # Build context
    context = context_builder.build

    # Call AI
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

