class AddFeedbackFieldsToFinMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :fin_messages, :feedback_rating, :integer
    add_column :fin_messages, :feedback_text, :string
    add_column :fin_messages, :was_helpful, :boolean
    add_column :fin_messages, :led_to_action, :boolean
    add_column :fin_messages, :tools_used, :jsonb
    add_column :fin_messages, :tool_success, :boolean
    add_column :fin_messages, :financial_decision_made, :boolean
    add_column :fin_messages, :decision_amount, :decimal, precision: 10, scale: 2

    add_index :fin_messages, :feedback_rating
    add_index :fin_messages, :was_helpful
    add_index :fin_messages, :led_to_action
  end
end
