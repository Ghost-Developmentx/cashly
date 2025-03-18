class CategoryFeedback < ApplicationRecord
  belongs_to :user
  belongs_to :transaction_record, class_name: "Transaction"
  belongs_to :suggested_category, class_name: "Category"
  belongs_to :chosen_category, class_name: "Category"

  validates :feedback_type, presence: true, inclusion: { in: %w[correction confirmation needs_improvement] }
end
