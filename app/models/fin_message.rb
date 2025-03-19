class FinMessage < ApplicationRecord
  belongs_to :fin_conversation

  # Validations
  validates :role, presence: true, inclusion: { in: %w[user assistant] }
  validates :content, presence: true

  # Scopes
  scope :user_messages, -> { where(role: "user") }
  scope :assistant_messages, -> { where(role: "assistant") }

  # Feedback scopes
  scope :with_feedback, -> { where.not(feedback_rating: nil) }
  scope :helpful, -> { where(was_helpful: true) }
  scope :unhelpful, -> { where(was_helpful: false) }
  scope :led_to_action, -> { where(led_to_action: true) }

  # Get all messages with a specific tool use
  scope :used_tool, ->(tool_name) { where("tools_used @> ?", [{name: tool_name}].to_json) }

  # Record a tool use
  def record_tool_use(tool_name, success)
    current_tools = tools_used || []
    current_tools << { name: tool_name, success: success, timestamp: Time.current }

    update(
      tools_used: current_tools,
      tool_success: success
    )
  end

  # Record that this message led to a financial decision
  def record_financial_decision(amount)
    update(
      led_to_action: true,
      financial_decision_made: true,
      decision_amount: amount
    )
  end
end
