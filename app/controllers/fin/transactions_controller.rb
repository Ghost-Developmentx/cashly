module Fin
  class TransactionsController < ApplicationController
    before_action :set_transaction, only: [:show, :update, :destroy]

    def index
      filters = params.permit(:account_id, :account_name, :days, :start_date, :end_date,
                              :category, :min_amount, :max_amount, :type, :limit)

      transactions = filter_user_transactions(current_user, filters)

      render json: {
        success: true,
        transactions: format_transactions_for_display(transactions),
        summary: calculate_transaction_summary(transactions, filters)
      }
    end

    def create
      @transaction = current_user.transactions.build

      # Find the account
      account = find_user_account(transaction_params[:account_id], transaction_params[:account_name])
      unless account
        render json: { success: false, error: "Account not found" }, status: :unprocessable_entity
        return
      end

      @transaction.account = account
      @transaction.assign_attributes(transaction_params.except(:account_name))

      # Auto-categorize if no category provided
      if @transaction.category_id.blank? && @transaction.description.present?
        category_response = AiService.categorize_transaction(
          @transaction.description,
          @transaction.amount,
          @transaction.date
        )

        if category_response.is_a?(Hash) && !category_response[:error]
          category_name = category_response["category"]
          category = Category.find_or_create_by(name: category_name)
          @transaction.category = category
          @transaction.ai_categorized = true
          @transaction.categorization_confidence = category_response["confidence"].to_f
        end
      end

      if @transaction.save
        render json: {
          success: true,
          message: "Transaction created successfully",
          transaction: format_single_transaction(@transaction)
        }
      else
        render json: {
          success: false,
          error: @transaction.errors.full_messages.join(", ")
        }, status: :unprocessable_entity
      end
    end

    def update
      # Only allow editing of manually created or AI-created transactions
      # Plaid transactions should be marked as read-only
      if @transaction.plaid_transaction_id.present?
        render json: {
          success: false,
          error: "Cannot edit transactions imported from your bank. These are automatically synced."
        }, status: :unprocessable_entity
        return
      end

      old_values = {
        amount: @transaction.amount,
        description: @transaction.description,
        category: @transaction.category&.name,
        date: @transaction.date
      }

      if @transaction.update(transaction_params.except(:account_name, :account_id))
        render json: {
          success: true,
          message: "Transaction updated successfully",
          transaction: format_single_transaction(@transaction),
          changes: calculate_changes(old_values, @transaction)
        }
      else
        render json: {
          success: false,
          error: @transaction.errors.full_messages.join(", ")
        }, status: :unprocessable_entity
      end
    end

    def destroy
      if @transaction.plaid_transaction_id.present?
        render json: {
          success: false,
          error: "Cannot delete transactions imported from your bank."
        }, status: :unprocessable_entity
        return
      end

      transaction_info = {
        description: @transaction.description,
        amount: @transaction.amount,
        account: @transaction.account.name
      }

      if @transaction.destroy
        render json: {
          success: true,
          message: "Transaction '#{transaction_info[:description]}' deleted successfully",
          deleted_transaction: transaction_info
        }
      else
        render json: {
          success: false,
          error: "Failed to delete transaction"
        }, status: :unprocessable_entity
      end
    end

    def categorize_bulk
      transaction_ids = params[:transaction_ids] || []

      if transaction_ids.empty?
        # Categorize all uncategorized transactions for user
        transactions = current_user.transactions.where(category_id: nil).limit(50)
      else
        transactions = current_user.transactions.where(id: transaction_ids)
      end

      # Schedule background job for categorization
      CategorizeTransactionsJob.perform_later(current_user.id, transactions.pluck(:id))

      render json: {
        success: true,
        message: "Categorizing #{transactions.count} transactions in the background",
        transaction_count: transactions.count
      }
    end

    def show
      render json: {
        success: true,
        transaction: format_single_transaction(@transaction, include_account: true)
      }
    end

    private

    def set_transaction
      @transaction = current_user.transactions.find(params[:id])
    end

    def transaction_params
      params.require(:transaction).permit(
        :account_id, :account_name, :amount, :date, :description,
        :category_id, :recurring, :notes
      )
    end

    def find_user_account(account_id, account_name)
      if account_id.present?
        current_user.accounts.find_by(id: account_id)
      elsif account_name.present?
        current_user.accounts.where("name ILIKE ?", "%#{account_name}%").first
      else
        nil
      end
    end

    def filter_user_transactions(user, filters)
      transactions = user.transactions.includes(:account, :category)

      # Account filter
      if filters[:account_id].present?
        transactions = transactions.where(account_id: filters[:account_id])
      elsif filters[:account_name].present?
        account = user.accounts.where("name ILIKE ?", "%#{filters[:account_name]}%").first
        transactions = transactions.where(account: account) if account
      end

      # Date range filter
      if filters[:start_date].present? && filters[:end_date].present?
        transactions = transactions.where(date: filters[:start_date]..filters[:end_date])
      elsif filters[:days].present?
        days_ago = filters[:days].to_i.days.ago.to_date
        transactions = transactions.where("date >= ?", days_ago)
      else
        # Default to last 30 days
        transactions = transactions.where("date >= ?", 30.days.ago.to_date)
      end

      # Category filter
      if filters[:category].present?
        transactions = transactions.joins(:category)
                                   .where("categories.name ILIKE ?", "%#{filters[:category]}%")
      end

      # Amount filters
      if filters[:min_amount].present?
        transactions = transactions.where("ABS(amount) >= ?", filters[:min_amount])
      end
      if filters[:max_amount].present?
        transactions = transactions.where("ABS(amount) <= ?", filters[:max_amount])
      end

      # Transaction type filter
      case filters[:type]
      when "income"
        transactions = transactions.where("amount > 0")
      when "expense"
        transactions = transactions.where("amount < 0")
      else
        # type code here
      end

      # Limit results
      limit = [filters[:limit].to_i, 100].min
      limit = 50 if limit <= 0

      transactions.order(date: :desc, created_at: :desc).limit(limit)
    end

    def format_transactions_for_display(transactions)
      transactions.map { |t| format_single_transaction(t) }
    end

    def format_single_transaction(transaction, include_account: false)
      formatted = {
        id: transaction.id,
        amount: transaction.amount.to_f,
        description: transaction.description,
        date: transaction.date.strftime("%Y-%m-%d"),
        category: transaction.category&.name || "Uncategorized",
        category_id: transaction.category_id,
        recurring: transaction.recurring || false,
        ai_categorized: transaction.ai_categorized || false,
        editable: transaction.plaid_transaction_id.blank?, # Can't edit Plaid transactions
        plaid_synced: transaction.plaid_transaction_id.present?,
        created_at: transaction.created_at.iso8601
      }

      if include_account
        formatted[:account] = {
          id: transaction.account.id,
          name: transaction.account.name,
          type: transaction.account.account_type
        }
      end

      formatted
    end

    def calculate_transaction_summary(transactions, filters)
      total_income = transactions.where("amount > 0").sum(:amount).to_f
      total_expenses = transactions.where("amount < 0").sum("ABS(amount)").to_f
      net_change = total_income - total_expenses

      # Category breakdown for expenses
      category_spending = transactions.joins(:category)
                                      .where("amount < 0")
                                      .group("categories.name")
                                      .sum("ABS(amount)")
                                      .transform_values(&:to_f)

      {
        count: transactions.count,
        total_income: total_income,
        total_expenses: total_expenses,
        net_change: net_change,
        date_range: determine_date_range(filters),
        category_breakdown: category_spending,
        filters_applied: filters.to_h
      }
    end

    def determine_date_range(filters)
      if filters[:start_date].present? && filters[:end_date].present?
        "#{filters[:start_date]} to #{filters[:end_date]}"
      elsif filters[:days].present?
        start_date = filters[:days].to_i.days.ago.to_date
        "#{start_date} to #{Date.current}"
      else
        start_date = 30.days.ago.to_date
        "#{start_date} to #{Date.current}"
      end
    end

    def calculate_changes(old_values, transaction)
      changes = {}

      changes[:amount] = { from: old_values[:amount].to_f, to: transaction.amount.to_f } if old_values[:amount] != transaction.amount
      changes[:description] = { from: old_values[:description], to: transaction.description } if old_values[:description] != transaction.description
      changes[:category] = { from: old_values[:category], to: transaction.category&.name } if old_values[:category] != transaction.category&.name
      changes[:date] = { from: old_values[:date].strftime("%Y-%m-%d"), to: transaction.date.strftime("%Y-%m-%d") } if old_values[:date] != transaction.date

      changes
    end
  end
end
