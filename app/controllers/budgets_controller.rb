class BudgetsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_budget, only: [ :show, :edit, :update, :destroy ]
  def index
    @budgets = current_user.budgets.includes(:category).order("categories.name")

    # Calculate totals
    @total_budget = @budgets.sum(:amount)

    # Get AI budget recommendations if we have transactions
    if current_user.transactions.exists?
      # Calculate monthly income (only positive transactions)
      monthly_income = current_user.transactions
                                   .where("date >= ? AND amount > 0", 1.month.ago)
                                   .sum(:amount)

      # Get budget transactions
      @budget_transactions = current_user.transactions.where("date >= ?", 3.months.ago)

      if @budget_transactions.present? && monthly_income > 0
        # Get budget recommendations
        @budget_recommendations = AiService.generate_budget(
          current_user.id,
          @budget_transactions,
          monthly_income
        )
      end
    end
  end

  def show
    # Get transactions in this category for the current month
    month_start = Date.today.beginning_of_month
    month_end = Date.today.end_of_month

    @month_transactions = Transaction.joins(:account)
                                     .where(category: @budget.category,
                                            accounts: { user_id: current_user.id },
                                            date: month_start..month_end)
                                     .order(date: :desc)

    # Calculate spending amount
    @spent_amount = @month_transactions.where("amount < 0").sum(:amount).abs
    @remaining_amount = @budget.amount - @spent_amount
    @percent_used = @budget.amount > 0 ? (@spent_amount / @budget.amount) * 100 : 0

    # Last 6 months history
    @months_history = []
    6.times do |i|
      month = Date.today - i.months
      month_start = month.beginning_of_month
      month_end = month.end_of_month

      month_spent = Transaction.joins(:account)
                               .where(category: @budget.category,
                                      accounts: { user_id: current_user.id },
                                      date: month_start..month_end)
                               .where("amount < 0")
                               .sum(:amount).abs

      @months_history.unshift({
                                month: month.strftime("%b %Y"),
                                spent: month_spent,
                                budget: @budget.amount,
                                percent: @budget.amount > 0 ? (month_spent / @budget.amount) * 100 : 0
                              })
    end
  end

  def new
    @budget = Budget.new
    @categories = Category.all.order(name: :asc)
    @budget.category_id = params[:category_id] if params[:category_id]

    # If we have transaction history, suggest budget amount
    if params[:category_id]
      category = Category.find(params[:category_id])

      # Calculate average spending in last 3 months
      three_months_ago = Date.today - 3.months
      transactions = Transaction.joins(:account)
                                .where(category: category,
                                       accounts: { user_id: current_user.id },
                                       date: three_months_ago)
                                .where("amount < 0")

      if transactions.any?
        # Group by month and calculate average
        monthly_spent = transactions.group_by { |t| t.date&.beginning_of_month }
                                    .reject { |k, v| k.nil? }
                                    .map { |_, txs| txs.sum(&:amount) }

        @suggested_amount = monthly_spent.sum / monthly_spent.size
      end
    end
  end

  def edit
    @categories = Category.all.order(name: :asc)
    @budget = current_user.budgets.find(params[:id])
  end

  def create
    @budget = current_user.budgets.build(budget_params)

    respond_to do |format|
      if @budget.save
        format.html { redirect_to budget_path(@budget), notice: "Budget was successfully created." }
        format.json { render :show, status: :created, location: @budget }
      else
        @categories = Category.all.order(name: :asc)
        format.html { render :new }
        format.json { render json: @budget.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if @budget.update(budget_params)
        format.html { redirect_to budget_path(@budget), notice: "Budget was successfully updated." }
        format.json { render :show, status: :ok, location: @budget }
      else
        format.html { render :edit }
        format.json { render json: @budget.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @budget.destroy
    respond_to do |format|
      format.html { redirect_to budgets_url, notice: "Budget was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def recommendations
    @budget_recommendations = {}

    # Get user transactions for budget analysis
    @budget_transactions = current_user.transactions.where("date >= ?", 3.months.ago)

    # Calculate monthly income (only positive transactions)
    monthly_income = current_user.transactions.where("date >= ? AND amount > 0", 1.month.ago).sum(:amount)

    # Only proceed if we have transactions and income
    if @budget_transactions.present? && monthly_income > 0
      budget_response = AiService.generate_budget(
        current_user.id,
        @budget_transactions,
        monthly_income
      )

      @budget_recommendations = budget_response.is_a?(Hash) ? budget_response : {}
    end

    respond_to do |format|
      format.html
      format.json { render json: @budget_recommendations }
    end
  end

  def apply_all_recommendations
    # Get budget recommendations
    @budget_transactions = current_user.transactions.where("date >= ?", 3.months.ago)
    monthly_income = current_user.transactions.where("date >= ? AND amount > 0", 1.month.ago).sum(:amount)

    if @budget_transactions.present? && monthly_income > 0
      budget_response = AiService.generate_budget(
        current_user.id,
        @budget_transactions,
        monthly_income
      )

      if budget_response.is_a?(Hash) && budget_response["recommended_budget"].present?
        # Apply each category recommendation
        created_count = 0
        updated_count = 0

        budget_response["recommended_budget"]["by_category"].each do |category_name, amount|
          # Find or create the category
          category = Category.find_by(name: category_name.downcase)

          unless category
            category = Category.create(name: category_name.downcase, description: "Auto-created from AI recommendation")
          end

          # Find or create the budget
          budget = current_user.budgets.find_or_initialize_by(category: category)
          is_new = budget.new_record?

          # Update budget amount
          budget.amount = amount
          budget.period_start = Date.today.beginning_of_month
          budget.period_end = Date.today.end_of_month

          if budget.save
            is_new ? created_count += 1 : updated_count += 1
          end
        end

        redirect_to budgets_path, notice: "Successfully created #{created_count} and updated #{updated_count} budgets based on AI recommendations."
      else
        redirect_to recommendations_budgets_path, alert: "Could not apply recommendations. Invalid recommendation data."
      end
    else
      redirect_to recommendations_budgets_path, alert: "Could not apply recommendations. Insufficient transaction data."
    end
  end

  private

  def set_budget
    @budget = current_user.budgets.find(params[:id])
  end

  def budget_params
    params.require(:budget).permit(:category_id, :amount, :period_start, :period_end)
  end
end
