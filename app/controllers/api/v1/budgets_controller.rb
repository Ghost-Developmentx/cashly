module Api
  module V1
    class BudgetsController < BaseController
      def index
        budgets = current_user.budgets.includes(:category)

        render_success(budgets.map { |b| serialize_budget(b) })
      end

      def show
        budget = current_user.budgets.find(params[:id])
        render_success(serialize_budget(budget, detailed: true))
      rescue ActiveRecord::RecordNotFound
        render_error("Budget not found", :not_found)
      end

      def create
        budget = current_user.budgets.build(budget_params)

        if budget.save
          render_success(serialize_budget(budget))
        else
          render_error(budget.errors.full_messages.join(", "))
        end
      end

      def update
        budget = current_user.budgets.find(params[:id])

        if budget.update(budget_params)
          render_success(serialize_budget(budget))
        else
          render_error(budget.errors.full_messages.join(", "))
        end
      rescue ActiveRecord::RecordNotFound
        render_error("Budget not found", :not_found)
      end

      def destroy
        budget = current_user.budgets.find(params[:id])
        budget.destroy
        render_success({ id: params[:id], deleted: true })
      rescue ActiveRecord::RecordNotFound
        render_error("Budget not found", :not_found)
      end

      def performance
        # Get budget performance for current month
        budgets = current_user.budgets.includes(:category)
        performance = budgets.map do |budget|
          spent = calculate_spent(budget)
          {
            budget_id: budget.id,
            category: budget.category.name,
            allocated: budget.amount.to_f,
            spent: spent,
            remaining: budget.amount.to_f - spent,
            percentage_used: budget.amount > 0 ? (spent / budget.amount * 100).round(2) : 0
          }
        end

        render_success(performance)
      end

      private

      def budget_params
        params.require(:budget).permit(:category_id, :amount, :period)
      end

      def serialize_budget(budget, detailed: false)
        data = {
          id: budget.id,
          category: budget.category.name,
          category_id: budget.category_id,
          amount: budget.amount.to_f,
          period: budget.period,
          created_at: budget.created_at,
          updated_at: budget.updated_at
        }

        if detailed
          spent = calculate_spent(budget)
          data[:performance] = {
            spent: spent,
            remaining: budget.amount.to_f - spent,
            percentage_used: budget.amount > 0 ? (spent / budget.amount * 100).round(2) : 0
          }

          data[:recent_transactions] = budget.category.transactions
                                             .where(account: current_user.accounts)
                                             .order(date: :desc)
                                             .limit(10)
                                             .map { |t| Api::V1::TransactionsController.new.send(:serialize_transaction, t) }
        end

        data
      end

      def calculate_spent(budget)
        start_date = case budget.period
                     when "monthly" then Date.current.beginning_of_month
                     when "weekly" then Date.current.beginning_of_week
                     when "yearly" then Date.current.beginning_of_year
                     else Date.current.beginning_of_month
                     end

        budget.category.transactions
              .where(account: current_user.accounts)
              .where("date >= ? AND amount < 0", start_date)
              .sum(:amount)
              .abs
      end
    end
  end
end