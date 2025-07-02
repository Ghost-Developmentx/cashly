module Api
  module V1
    class TransactionsController < BaseController
      def index
        transactions = current_user.transactions
        transactions = apply_filters(transactions)
        transactions = transactions.order(date: :desc)

        # Apply pagination
        page = pagination_params
        transactions = transactions.limit(page[:limit]).offset(page[:offset])

        render_success(
          transactions.map { |t| serialize_transaction(t) },
          {
            total: current_user.transactions.count,
            filtered: transactions.count,
            limit: page[:limit],
            offset: page[:offset]
          }
        )
      end

      def show
        transaction = current_user.transactions.find(params[:id])
        render_success(serialize_transaction(transaction))
      rescue ActiveRecord::RecordNotFound
        render_error("Transaction not found", :not_found)
      end

      def create
        transaction = current_user.accounts.first.transactions.build(transaction_params)

        if transaction.save
          render_success(serialize_transaction(transaction))
        else
          render_error(transaction.errors.full_messages.join(", "))
        end
      end

      def update
        transaction = current_user.transactions.find(params[:id])

        if transaction.update(transaction_params)
          render_success(serialize_transaction(transaction))
        else
          render_error(transaction.errors.full_messages.join(", "))
        end
      rescue ActiveRecord::RecordNotFound
        render_error("Transaction not found", :not_found)
      end

      def destroy
        transaction = current_user.transactions.find(params[:id])
        transaction.destroy
        render_success({ id: params[:id], deleted: true })
      rescue ActiveRecord::RecordNotFound
        render_error("Transaction not found", :not_found)
      end

      def summary
        transactions = current_user.transactions
        transactions = apply_filters(transactions)

        summary = {
          total_income: transactions.where("amount > 0").sum(:amount),
          total_expenses: transactions.where("amount < 0").sum(:amount).abs,
          transaction_count: transactions.count,
          category_breakdown: calculate_category_breakdown(transactions),
          date_range: {
            from: params[:from_date] || 30.days.ago.to_date,
            to: params[:to_date] || Date.current
          }
        }

        render_success(summary)
      end

      private

      def apply_filters(scope)
        # Date filters
        if params[:from_date].present?
          scope = scope.where("date >= ?", params[:from_date])
        end

        if params[:to_date].present?
          scope = scope.where("date <= ?", params[:to_date])
        end

        # Account filter
        if params[:account_id].present?
          scope = scope.where(account_id: params[:account_id])
        end

        # Category filter
        if params[:category].present?
          scope = scope.joins(:category).where("categories.name ILIKE ?", "%#{params[:category]}%")
        end

        # Amount filters
        if params[:min_amount].present?
          scope = scope.where("ABS(amount) >= ?", params[:min_amount].to_f)
        end

        if params[:max_amount].present?
          scope = scope.where("ABS(amount) <= ?", params[:max_amount].to_f)
        end

        # Transaction type filter
        case params[:transaction_type]
        when "income"
          scope = scope.where("amount > 0")
        when "expense"
          scope = scope.where("amount < 0")
        end

        scope
      end

      def calculate_category_breakdown(transactions)
        transactions
          .joins(:category)
          .where("amount < 0")
          .group("categories.name")
          .sum("ABS(amount)")
      end

      def transaction_params
        params.require(:transaction).permit(:amount, :description, :date, :category_id, :account_id, :recurring)
      end

      def serialize_transaction(transaction)
        {
          id: transaction.id,
          amount: transaction.amount.to_f,
          description: transaction.description,
          date: transaction.date.to_s,
          category: transaction.category&.name || "Uncategorized",
          category_id: transaction.category_id,
          account_id: transaction.account_id,
          account_name: transaction.account.name,
          recurring: transaction.recurring || false,
          created_at: transaction.created_at,
          updated_at: transaction.updated_at,
          plaid_transaction_id: transaction.plaid_transaction_id
        }
      end
    end
  end
end