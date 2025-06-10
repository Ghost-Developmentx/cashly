module FinancialAI
  class RecordFeedback < BaseOperation
    attr_reader :user, :message_id, :feedback_type, :rating

    validates :user, presence: true
    validates :message_id, presence: true
    validates :feedback_type, presence: true

    def initialize(user:, message_id:, feedback_type:, rating: nil)
      @user = user
      @message_id = message_id
      @feedback_type = feedback_type
      @rating = rating
    end

    def execute
      message = find_message

      message.update!(
        feedback_rating: rating,
        feedback_text: feedback_type,
        was_helpful: feedback_type == "helpful"
      )

      # Update learning metrics
      update_learning_metrics

      success(message: "Thank you for your feedback!")
    end

    private

    def find_message
      if message_id.start_with?("temp-")
        # Handle temporary IDs from frontend
        conversation = user.fin_conversations.active.first
        conversation.fin_messages
                    .where(role: "assistant")
                    .order(created_at: :desc)
                    .first
      else
        user.fin_conversations
            .joins(:fin_messages)
            .find_by(fin_messages: { id: message_id })
            .fin_messages
            .find(message_id)
      end
    end

    def update_learning_metrics
      # This could be expanded to track metrics over time
      Rails.logger.info "[Feedback] Message #{message_id}: #{feedback_type} (rating: #{rating})"
    end
  end
end