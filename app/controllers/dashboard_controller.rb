class DashboardController < ApplicationController
  before_action :authenticate_user!
  def index
    # Calculate user account balances
    @total_balance = current_user.accounts.sum(&:balance)

    # Calculate monthly income and expenses
    month_start = Time.now.beginning_of_month
    month_end = Time.now.end_of_month

    @monthly_income = current_user.transactions
                                  .where("date >= ? AND date <= ? AND amount > 0", month_start, month_end)
                                  .sum(:amount)

    @monthly_expenses = current_user.transactions
                                    .where("date >= ? AND date <= ? AND amount < 0", month_start, month_end)
                                    .sum(:amount).abs

    # Get recent transactions for sidebar
    @recent_transactions = current_user.transactions.order(date: :desc).limit(5)

    # Get active budgets
    @budgets = current_user.budgets.includes(:category).order("categories.name").limit(3)

    # Prepare data for ApexChart Stimulus controllers
    @cash_flow_data = prepare_cash_flow_data
    @category_spending_data = prepare_category_spending_data
    @budget_vs_actual_data = prepare_budget_vs_actual_data

    # Check if we need to show onboarding elements
    @show_onboarding = needs_onboarding_guidance?

    # Check if we need to show tutorial
    @show_tutorial = current_user.onboarding_completed? && !current_user.tutorial_completed?

    respond_to do |format|
      format.html
      format.json { render json: { success: true } }
    end
  end

  def cash_flow
    days = params[:days].present? ? params[:days].to_i : 30

    render json: { data: prepare_cash_flow_data(days) }
  end


  def category_spending
    timeframe = params[:timeframe] || "month"

    render json: { data: prepare_category_spending_data(timeframe) }
  end

  def budget_vs_actual
    render json: { data: prepare_budget_vs_actual_data }
  end

  def hide_getting_started
    # Set a session variable to hide the getting started guide
    session[:hide_getting_started] = true

    respond_to do |format|
      format.json { render json: { success: true } }
      format.html { redirect_back(fallback_location: dashboard_path) }
    end
  end

  private

  def prepare_cash_flow_data(days = 30)
    start_date = Date.today - days.days

    # Get all transactions within the date range
    transactions = current_user.transactions.where("date >= ?", start_date).order(:date)

    # Group transactions by date
    daily_data = {}

    # Initialize with all dates in range
    (start_date..Date.today).each do |date|
      date_str = date.strftime("%b %d") # Format as "Jan 01" for better display
      daily_data[date_str] = { date: date_str, income: 0, expenses: 0, net: 0 }
    end

    # Aggregate transactions by date
    transactions.each do |transaction|
      date_str = transaction.date.strftime("%b %d")

      # Skip transactions with dates outside our initialized range
      next unless daily_data[date_str]

      amount = transaction.amount

      if amount >= 0
        daily_data[date_str][:income] += amount
      else
        daily_data[date_str][:expenses] += amount.abs
      end

      daily_data[date_str][:net] += amount
    end

    # Format for ApexCharts line chart
    result = {
      dates: daily_data.keys,
      series: [
        {
          name: "Net Cash Flow",
          data: daily_data.values.map { |d| d[:net].round(2) }
        },
        {
          name: "Income",
          data: daily_data.values.map { |d| d[:income].round(2) }
        },
        {
          name: "Expenses",
          data: daily_data.values.map { |d| d[:expenses].round(2) }
        }
      ]
    }
  end

  def prepare_category_spending_data(timeframe = "month")
    # Determine time period based on parameter
    case timeframe
    when "month"
      start_date = Date.today.beginning_of_month
    when "quarter"
      start_date = Date.today.beginning_of_quarter
    when "year"
      start_date = Date.today.beginning_of_year
    else
      start_date = Date.today.beginning_of_month
    end

    # Get all expense transactions within the date range
    transactions = current_user.transactions
                               .where("date >= ? AND amount < 0", start_date)
                               .includes(:category)

    # Group by category and sum amounts
    category_data = {}

    transactions.each do |transaction|
      category_name = transaction.category&.name || "Uncategorized"

      category_data[category_name] ||= 0
      category_data[category_name] += transaction.amount.abs
    end

    # Convert to array format for ApexCharts pie chart
    result = category_data.map { |name, value| { name: name, value: value.round(2) } }
                          .sort_by { |item| -item[:value] } # Sort by value descending
                          .take(8) # Limit to top 8 categories for better visibility

    # Add "Other" category for the remaining categories if needed
    if category_data.size > 8
      other_total = category_data.sort_by { |_, value| -value }[8..-1].sum { |_, value| value }
      result << { name: "Other", value: other_total.round(2) } if other_total > 0
    end

    # Format for ApexCharts pie chart
    {
      series: result.map { |item| item[:value] },
      labels: result.map { |item| item[:name] }
    }
  end

  def prepare_budget_vs_actual_data
    # Get current month data
    start_date = Date.today.beginning_of_month
    end_date = Date.today.end_of_month

    # Get all budgets for the user
    budgets = current_user.budgets.includes(:category)

    data = []

    budgets.each do |budget|
      category_name = budget.category.name
      budget_amount = budget.amount

      # Calculate actual spending for this category in the current month
      actual_spending = current_user.transactions
                                    .where(category: budget.category, date: start_date..end_date)
                                    .where("amount < 0") # Only expenses
                                    .sum(:amount).abs

      data << {
        category: category_name,
        budget: budget_amount.round(2),
        actual: actual_spending.round(2)
      }
    end

    # Sort by percentage of budget used (actual/budget) in descending order
    data = data.sort_by { |item| -(item[:actual] / item[:budget]) rescue 0 }
               .take(10) # Limit to top 10 categories

    # Format for ApexCharts bar chart
    {
      categories: data.map { |item| item[:category] },
      series: [
        {
          name: "Budget",
          data: data.map { |item| item[:budget] }
        },
        {
          name: "Actual",
          data: data.map { |item| item[:actual] }
        }
      ]
    }
  end

  def get_top_spending_categories(start_date, end_date, limit = 5)
    # Get all expense transactions with categories
    transactions = current_user.transactions
                               .where("date >= ? AND date <= ? AND amount < 0", start_date, end_date)
                               .includes(:category)

    # Group by category and sum amounts
    category_totals = {}

    transactions.each do |transaction|
      category_name = transaction.category&.name || "Uncategorized"

      category_totals[category_name] ||= 0
      category_totals[category_name] += transaction.amount.abs
    end

    # Convert to array and sort
    category_totals.map { |name, amount| { name: name, amount: amount } }
                   .sort_by { |item| -item[:amount] }
                   .take(limit)
  end

  def needs_onboarding_guidance?
    # Show onboarding guidance if any of these are true:
    # 1. No accounts
    # 2. No transactions
    # 3. No budgets
    # But respect the user's choice to hide it
    return false if session[:hide_getting_started]

    current_user.accounts.none? ||
      current_user.transactions.none? ||
      current_user.budgets.none?
  end
end
