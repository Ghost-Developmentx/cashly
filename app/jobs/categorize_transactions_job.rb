class CategorizeTransactionsJob < ApplicationJob
  queue_as :default

  def perform(user_id, transaction_ids = nil)
    user = User.find_by(id: user_id)
    return unless user

    # Get uncategorized transactions
    transactions = if transaction_ids.present?
                     user.transactions.where(id: transaction_ids, category_id: nil)
    else
                     user.transactions.where(category_id: nil).limit(50)
    end

    return if transactions.empty?

    transactions.each do |transaction|
      # Skip if already processed
      next if transaction.ai_categorized

      # Call AI service
      category_response = AiService.categorize_transaction(
        transaction.description,
        transaction.amount,
        transaction.date
      )

      # Process response
      if category_response.is_a?(Hash) && !category_response[:error]
        category_name = category_response["category"]
        confidence = category_response["confidence"].to_f

        category = Category.find_or_create_by(name: category_name)

        transaction.update(
          category: category,
          ai_categorized: true,
          categorization_confidence: confidence
        )
      end
    end
  end
end
