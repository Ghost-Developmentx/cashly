class CategoryAccountMapping < ApplicationRecord
  # Relationships
  belongs_to :category
  belongs_to :ledger_account

  # Validations
  validates :category_id, uniqueness: { scope: :ledger_account_id }

  # Custom validation to ensure the category is mapped to an appropriate account type
  validate :validate_account_type_for_category

  private

  def validate_account_type_for_category
    # Most categories should map to expense accounts, but income categories
    # should map to revenue accounts
    if category.present? && ledger_account.present?
      # This is a simplified validation - you may need to adjust based on your category structure
      if category.name.downcase.include?("income") || category.name.downcase.include?("revenue")
        unless ledger_account.account_type == "revenue"
          errors.add(:ledger_account, "must be a revenue account for income categories")
        end
      else
        unless ledger_account.account_type == "expense"
          errors.add(:ledger_account, "must be an expense account for expense categories")
        end
      end
    end
  end
end
