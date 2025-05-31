class FinConversation < ApplicationRecord
  belongs_to :user
  has_many :fin_messages, -> { order(created_at: :asc) }, dependent: :destroy
  scope :active, -> { where(active: true) }

  # Serialize the conversation history to the format expected by the FinService
  def conversation_history
    fin_messages.map do |message|
      {
        role: message.role,
        content: message.content
      }
    end
  end

  # Add a new message to the conversation
  def add_message(role, content)
    fin_messages.create(role: role, content: content)
  end

  # Create a new conversation with an initial user message
  def self.start_conversation(user, query)
    conversation = user.fin_conversations.create
    conversation.add_message("user", query)
    conversation
  end
end
