class CategorizeTransactionsJob < ApplicationJob
  queue_as :default

  def perform(user_id, transaction_ids = nil)
    user = User.find_by(id: user_id)
    return unless user

    transactions = if transaction_ids.present?
                     Transaction.where(id: transaction_ids, category_id: nil)
                   else
                     user.transactions.where(category_id: nil).limit(50)
                   end

    return if transactions.empty?

    transactions.each do |transaction|
      categorize_single_transaction(transaction)
    end
  end

  private

  def categorize_single_transaction(transaction)
    # Skip if already categorized
    return if transaction.ai_categorized || transaction.category_id.present?

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

      Rails.logger.info "Categorized transaction #{transaction.id} as #{category_name} (confidence: #{confidence})"
    else
      Rails.logger.error "Failed to categorize transaction #{transaction.id}: #{category_response[:error]}"
    end
  rescue StandardError => e
    Rails.logger.error "Error categorizing transaction #{transaction.id}: #{e.message}"
  end
end
