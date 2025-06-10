module FinancialAI
  class GetConversationHistory < BaseOperation
    attr_reader :user

    validates :user, presence: true

    def initialize(user:)
      @user = user
    end

    def execute
      conversations = user.fin_conversations
                          .order(created_at: :desc)
                          .limit(20)

      success(
        conversations: present_conversations(conversations)
      )
    end

    private

    def present_conversations(conversations)
      conversations.map do |conversation|
        {
          id: conversation.id,
          title: conversation.title || "Untitled Conversation",
          created_at: conversation.created_at.iso8601,
          updated_at: conversation.updated_at.iso8601,
          active: conversation.active,
          message_count: conversation.fin_messages.count
        }
      end
    end
  end
end
