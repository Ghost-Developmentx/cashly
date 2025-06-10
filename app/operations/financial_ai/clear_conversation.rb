module FinancialAI
  class ClearConversation < BaseOperation
    attr_reader :user

    validates :user, presence: true

    def initialize(user:)
      @user = user
    end

    def execute
      # Deactivate all active conversations
      user.fin_conversations.where(active: true).update_all(active: false)

      # Create a new active conversation
      new_conversation = user.fin_conversations.create!(active: true)

      success(
        conversation_id: new_conversation.id,
        message: "Started a new conversation."
      )
    end
  end
end
