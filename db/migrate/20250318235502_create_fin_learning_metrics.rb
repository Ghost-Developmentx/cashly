class CreateFinLearningMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :fin_learning_metrics do |t|
      t.integer :total_messages, default: 0
      t.integer :feedback_messages, default: 0
      t.integer :helpful_messages, default: 0
      t.integer :tools_used, default: 0
      t.integer :tools_success, default: 0
      t.text :top_success_patterns, default: "{}"
      t.text :top_failure_patterns, default: "{}"
      t.timestamps
    end

    add_index :fin_learning_metrics, :created_at
  end
end
