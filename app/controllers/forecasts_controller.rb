# app/controllers/forecasts_controller.rb
class ForecastsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_forecast, only: [ :show, :edit, :update, :destroy, :compare ]

  def index
    @forecasts = current_user.forecasts.order(created_at: :desc)
    @default_forecast = generate_default_forecast
  end

  def show
    @data = JSON.parse(@forecast.result_data)

    respond_to do |format|
      format.html
      format.json { render json: @data }
    end
  end

  def new
    @forecast = Forecast.new
    @categories = Category.all.order(:name)
  end

  def create
    @forecast = current_user.forecasts.new(forecast_params)

    # Get transactions for forecasting
    transactions = current_user.transactions.where(date: 90.days.ago..Date.today)
                               .includes(:category)

    # Filter transactions by included categories if specified
    if params[:included_category_ids].present?
      @forecast.included_category_ids = params[:included_category_ids]
      transactions = transactions.where(category_id: params[:included_category_ids])
    end

    formatted_transactions = transactions.map do |t|
      {
        date: t.date.to_s,
        amount: t.amount.to_f,
        category: t.category&.name || "uncategorized"
      }
    end

    forecast_result = AiService.forecast_cash_flow(
      current_user.id,
      formatted_transactions,
      @forecast.time_horizon
    )

    if forecast_result.is_a?(Hash) && !forecast_result[:error]
      @forecast.result_data = forecast_result.to_json

      if @forecast.save
        redirect_to @forecast, notice: "Forecast was successfully created."
      else
        @categories = Category.all.order(:name)
        render :new
      end
    else
      @categories = Category.all.order(:name)
      flash.now[:alert] = "Could not generate forecast at this time."
      render :new
    end
  end

  def edit
    @categories = Category.all.order(:name)
  end

  def update
    if @forecast.update(forecast_params)
      # Regenerate forecast with updated parameters
      regenerate_forecast
      redirect_to @forecast, notice: "Forecast was successfully updated."
    else
      @categories = Category.all.order(:name)
      render :edit
    end
  end

  def destroy
    @forecast.destroy
    redirect_to forecasts_path, notice: "Forecast was successfully deleted."
  end

  def compare
    @comparison_id = params[:comparison_id]
    @comparison_forecast = current_user.forecasts.find_by(id: @comparison_id)

    if @comparison_forecast.nil?
      redirect_to @forecast, alert: "Comparison forecast not found."
      return
    end

    @forecast_data = JSON.parse(@forecast.result_data)
    @comparison_data = JSON.parse(@comparison_forecast.result_data)

    # Combine data for display
    @combined_data = {
      dates: @forecast_data["forecast"].map { |f| f["date"] },
      forecast_series: @forecast_data["forecast"].map { |f| f["balance"] },
      comparison_series: @comparison_data["forecast"].map { |f| f["balance"] }
    }

    respond_to do |format|
      format.html
      format.json { render json: @combined_data }
    end
  end

  def scenarios
    @forecast = current_user.forecasts.find(params[:id])
    @scenarios = current_user.forecasts.where(scenario_type: "scenario").order(created_at: :desc)
  end

  def create_scenario
    @original_forecast = current_user.forecasts.find(params[:id])

    # Create a new scenario based on original forecast
    @scenario = current_user.forecasts.new(
      name: "#{@original_forecast.name} - Scenario",
      description: params[:description],
      time_horizon: @original_forecast.time_horizon,
      included_category_ids: @original_forecast.included_category_ids,
      scenario_type: "scenario"
    )

    # Get transactions for forecasting with adjustments
    transactions = current_user.transactions.where(date: 90.days.ago..Date.today)
                               .includes(:category)

    # Filter transactions by included categories if specified
    if @original_forecast.included_category_ids.present?
      transactions = transactions.where(category_id: @original_forecast.included_category_ids)
    end

    formatted_transactions = transactions.map do |t|
      {
        date: t.date.to_s,
        amount: t.amount.to_f,
        category: t.category&.name || "uncategorized"
      }
    end

    # Apply scenario adjustments from params
    adjustments = {
      category_adjustments: params[:category_adjustments],
      income_adjustment: params[:income_adjustment].to_f,
      expense_adjustment: params[:expense_adjustment].to_f,
      recurring_transactions: params[:recurring_transactions]
    }

    # Call AI service with scenario parameters
    forecast_result = AiService.forecast_cash_flow_scenario(
      current_user.id,
      formatted_transactions,
      @scenario.time_horizon,
      adjustments
    )

    if forecast_result.is_a?(Hash) && !forecast_result[:error]
      @scenario.result_data = forecast_result.to_json

      if @scenario.save
        redirect_to compare_forecast_path(@original_forecast, comparison_id: @scenario.id),
                    notice: "Scenario was successfully created."
      else
        redirect_to @original_forecast, alert: "Could not create scenario."
      end
    else
      redirect_to @original_forecast, alert: "Could not generate scenario forecast."
    end
  end

  private

  def set_forecast
    @forecast = current_user.forecasts.find(params[:id])
  end

  def forecast_params
    params.require(:forecast).permit(:name, :description, :time_horizon, included_category_ids: [])
  end

  def regenerate_forecast
    # Get transactions for forecasting
    transactions = current_user.transactions.where(date: 90.days.ago..Date.today)
                               .includes(:category)

    # Filter transactions by included categories if specified
    if @forecast.included_category_ids.present?
      transactions = transactions.where(category_id: @forecast.included_category_ids)
    end

    formatted_transactions = transactions.map do |t|
      {
        date: t.date.to_s,
        amount: t.amount.to_f,
        category: t.category&.name || "uncategorized"
      }
    end

    forecast_result = AiService.forecast_cash_flow(
      current_user.id,
      formatted_transactions,
      @forecast.time_horizon
    )

    if forecast_result.is_a?(Hash) && !forecast_result[:error]
      @forecast.update(result_data: forecast_result.to_json)
    end
  end

  def generate_default_forecast
    # Check for an existing recent default forecast
    default_forecast = current_user.forecasts.where(scenario_type: "default")
                                   .where("created_at > ?", 1.day.ago)
                                   .order(created_at: :desc)
                                   .first

    return default_forecast if default_forecast.present?

    # Create a new default forecast
    forecast = current_user.forecasts.new(
      name: "Default 30-Day Forecast",
      description: "Automatically generated 30-day forecast",
      time_horizon: 30,
      scenario_type: "default"
    )

    # Get transactions for forecasting
    transactions = current_user.transactions.where(date: 90.days.ago..Date.today)
                               .includes(:category)

    formatted_transactions = transactions.map do |t|
      {
        date: t.date.to_s,
        amount: t.amount.to_f,
        category: t.category&.name || "uncategorized"
      }
    end

    # Skip if there are no transactions
    return nil if formatted_transactions.empty?

    forecast_result = AiService.forecast_cash_flow(
      current_user.id,
      formatted_transactions,
      forecast.time_horizon
    )

    if forecast_result.is_a?(Hash) && !forecast_result[:error]
      forecast.result_data = forecast_result.to_json
      forecast.save
      return forecast
    end

    nil
  end
end
