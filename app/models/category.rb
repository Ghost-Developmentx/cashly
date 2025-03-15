class Category < ApplicationRecord
  belongs_to :parent_category, class_name: "Category", optional: true

  has_many :subcategories, class_name: "Category", foreign_key: :parent_category_id
  has_many :transactions

  # Add new relationship for Chart of Accounts
  has_many :category_account_mappings, dependent: :destroy
  has_many :ledger_accounts, through: :category_account_mappings

  # Helper method to get the primary ledger account
  def primary_ledger_account
    ledger_accounts.first
  end

  # Helper method to set the primary ledger account
  def primary_ledger_account=(ledger_account)
    transaction do
      category_account_mappings.destroy_all
      ledger_accounts << ledger_account if ledger_account.present?
    end
  end

  # Helper method to determine if this is an income category
  def income_category?
    name.downcase.include?("income") ||
      name.downcase.include?("revenue") ||
      name.downcase.include?("salary")
  end
end