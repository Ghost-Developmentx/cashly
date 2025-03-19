class FinController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation, only: [ :query ]

  # Show the chat interface
  def index
    # Get the active conversation or the most recent one
    @conversation = current_user.fin_conversations.where(active: true).first ||
      current_user.fin_conversations.order(created_at: :desc).first

    # Get conversation messages
    @conversation_history = @conversation ? @conversation.conversation_history : []

    # Pass data for any charts that might be needed
    prepare_dashboard_data
  end

  # Process a new user query
  def query
    query_text = params[:query]

    # Add user message to conversation
    @conversation.add_message("user", query_text)

    # Process the query through our FinService
    response = FinService.process_query(
      current_user.id,
      query_text,
      @conversation.conversation_history
    )

    # Check for errors
    if response[:error].present?
      render json: { error: response[:error] }, status: :unprocessable_content
      return
    end

    # Add assistant response to conversation
    @conversation.add_message("assistant", response["response_text"])

    # Update conversation title if this is the first exchange
    if @conversation.title.blank? && @conversation.fin_messages.count == 2
      # Set the title based on the first user message
      @conversation.update(title: query_text.truncate(50))
    end

    # Process any actions that might be needed
    actions = process_actions(response["actions"])

    # Return response to the client
    render json: {
      message: response["response_text"],
      actions: actions,
      conversation_history: @conversation.conversation_history
    }
  end

  # Clear conversation history
  def clear
    # Mark any active conversations as inactive
    current_user.fin_conversations.where(active: true).update_all(active: false)

    # Redirect back to Fin
    redirect_to fin_path, notice: "Started a new conversation with Fin."
  end

  def history
    @conversations = current_user.fin_conversations.order(created_at: :desc)
  end

  # Load a specific conversation
  def show
    @conversation = current_user.fin_conversations.find(params[:id])
    @conversation.update(active: true)

    # Deactivate all other conversations
    current_user.fin_conversations.where.not(id: @conversation.id).update_all(active: false)

    redirect_to fin_path
  end

  def feedback
    message_id = params[:message_id]
    feedback_type = params[:feedback]
    rating = params[:rating]

    # If the message_id starts with "temp-", it's a temporary ID, and we need to find the actual message
    if message_id.start_with?("temp-")
      # Find the most recent assistant message in the active conversation
      conversation = current_user.fin_conversations.where(active: true).first
      message = conversation&.fin_messages&.where(role: "assistant")&.order(created_at: :desc)&.first
    else
      # Find the specific message
      message = FinMessage.find_by(id: message_id)
    end

    if message
      # Update the message with feedback
      was_helpful = feedback_type == "helpful"

      message.update(
        feedback_rating: rating,
        feedback_text: feedback_type,
        was_helpful: was_helpful
      )

      # If this is labeled helpful, we can use it for learning
      if was_helpful && rating >= 4
        # You might want to trigger some learning process here or flag for future learning
      end

      render json: { success: true }
    else
      render json: { success: false, error: "Message not found" }, status: :not_found
    end
  end

  private

  def set_conversation
    # Get the active conversation or create a new one
    @conversation = current_user.fin_conversations.where(active: true).first

    if @conversation.nil?
      @conversation = current_user.fin_conversations.create(active: true)
    end
  end

  def prepare_dashboard_data
    # Prepare data for charts that might be used by Fin
    # Similar to what we do in DashboardController

    # Cash Flow Data for potential forecasts
    @cash_flow_data = {
      dates: [],
      series: [
        { name: "Net Cash Flow", data: [] },
        { name: "Income", data: [] },
        { name: "Expenses", data: [] }
      ]
    }

    # Category Spending Data
    @category_spending_data = {
      series: [],
      labels: []
    }

    # Budget vs Actual Data
    @budget_vs_actual_data = {
      categories: [],
      series: [
        { name: "Budget", data: [] },
        { name: "Actual", data: [] }
      ]
    }
  end

  def process_actions(actions)
    return [] unless actions.present?

    processed_actions = []

    actions.each do |action|
      case action["type"]
      when "show_forecast"
        # Create or update a forecast based on the data
        forecast = save_forecast(action["data"])
        processed_actions << { type: "redirect", url: forecast_path(forecast) } if forecast

      when "show_trends"
        # Process trend data for display
        processed_actions << { type: "update_chart", chart_id: "trends_chart", data: action["data"] }

      when "show_budget"
        # Process budget data for display
        processed_actions << { type: "update_chart", chart_id: "budget_chart", data: action["data"] }
      else
        # type code here
      end
    end

    processed_actions
  end

  def track_financial_impact
    # When a user takes action after Fin's recommendation
    # (e.g., creates a budget, approves a forecast)
    message_id = params[:message_id]
    action_type = params[:action_type]
    amount = params[:amount]

    message = FinMessage.find(message_id)
    message.update(
      led_to_action: true,
      financial_decision_made: true,
      decision_amount: amount
    )

    # This data becomes extremely valuable for fine-tuning
  end

  def save_forecast(forecast_data)
    return nil unless forecast_data.present?

    # Create a new forecast from the data
    forecast = current_user.forecasts.new(
      name: "Fin Forecast: #{Time.now.strftime('%b %d, %Y')}",
      description: "Created by Fin based on your query",
      time_horizon: forecast_data["forecast"].size,
      scenario_type: "scenario",
      result_data: forecast_data.to_json
    )

    if forecast.save
      forecast
    else
      nil
    end
  end
end
