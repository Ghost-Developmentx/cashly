module FinancialAI
  class ProcessQuery < BaseOperation
    attr_reader :user, :query, :conversation

    validates :user, presence: true
    validates :query, presence: true

    def initialize(user:, query:, conversation: nil)
      @user = user
      @query = query
      @conversation = conversation || find_or_create_conversation
    end

    def execute
      # Add user message
      conversation.add_message("user", query)

      # Build context and query AI
      context = build_context
      ai_response = query_ai(context)

      # Process response
      if ai_response.success?
        actions = process_ai_response(ai_response)
        response_text = ai_response.message

        # Add assistant message
        assistant_message = conversation.add_message("assistant", response_text)
        record_tool_usage(assistant_message, ai_response.tool_results)

        # Update conversation metadata
        update_conversation_metadata

        success(
          message: response_text,
          actions: actions,
          conversation_id: conversation.id,
          conversation_history: conversation.conversation_history
        )
      else
        failure(ai_response.error_message)
      end
    end

    private

    def find_or_create_conversation
      user.fin_conversations.active.first ||
        user.fin_conversations.create!(active: true)
    end

    def build_context
      FinancialAI::ConversationContext.new(user, conversation).build
    end

    def query_ai(context)
      client = FinancialAI::AiClient.new
      raw_response = client.query(
        user_id: user.id,
        query: query,
        conversation_history: conversation.conversation_history,
        transactions: context[:transactions],
        user_context: context[:user_context]
      )

      FinancialAI::AiResponse.new(raw_response)
    end

    def process_ai_response(ai_response)
      processor = FinancialAI::ResponseProcessor.new(user)
      processor.process(ai_response)
    end

    def record_tool_usage(message, tool_results)
      return if tool_results.blank?

      tools_used = tool_results.map do |result|
        {
          name: result["tool"],
          success: !result["result"].key?("error"),
          timestamp: Time.current
        }
      end

      message.update(tools_used: tools_used)
    end

    def update_conversation_metadata
      if conversation.title.blank? && conversation.fin_messages.count == 2
        conversation.update(title: query.truncate(50))
      end
    end
  end
end
