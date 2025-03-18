class AddAiCategoryFieldsToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :ai_categorized, :boolean, default: false
    add_column :transactions, :categorization_confidence, :float
  end
end
