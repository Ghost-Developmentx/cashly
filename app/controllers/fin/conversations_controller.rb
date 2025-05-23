# app/controllers/fin/conversations_controller.rb
module Fin
  class ConversationsController < ApplicationController
    before_action :set_conversation, only: [ :query ]

  # Show the chat interface
  def index
    # Get the active conversation or the most recent one
    @conversation = current_user.fin_conversations.where(active: true).first ||
      current_user.fin_conversations.order(created_at: :desc).first

    # Get conversation history
    @conversation_history = @conversation ? @conversation.conversation_history : []

    # Pass data for any charts that might be needed
    prepare_dashboard_data
  end

  # Process a new user query
  def query
    query_text = params[:query]

    # Add a user message to a conversation
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

    # Update the conversation title if this is the first exchange
    if @conversation.title.blank? && @conversation.fin_messages.count == 2
      # Set the title based on the first user message
      @conversation.update(title: query_text.truncate(50))
    end

    # Extract actions from the response
    actions = process_actions(response["actions"])

    # Find or instantiate the most recent assistant message
    assistant_message = @conversation.fin_messages.where(role: "assistant").order(created_at: :desc).first

    # Record tool usage for learning
    if response["tool_results"].present? && assistant_message
      assistant_message.update(
        tools_used: response["tool_results"].map do |result|
          {
            name: result["tool"],
            success: !result["result"].key?("error"),
            timestamp: Time.current
          }
        end
      )
    end

    # Return response to the client
    render json: {
      message: response["response_text"],
      actions: actions,
      conversation_history: @conversation.conversation_history
    }
  end

    def clear
      # Mark any active conversations as inactive
      current_user.fin_conversations.where(active: true).update_all(active: false)

      # Return JSON response directly (no respond_to needed in API-only mode)
      render json: { success: true, message: "Started a new conversation." }
    end

    def history
      conversations = current_user.fin_conversations.order(created_at: :desc)
      render json: conversations.as_json(only: [:id, :title, :created_at, :updated_at, :active])
    end


    def show
      @conversation = current_user.fin_conversations.find(params[:id])
      @conversation.update(active: true)
      current_user.fin_conversations.where.not(id: @conversation.id).update_all(active: false)

      # Format messages for frontend consumption
      formatted_messages = @conversation.fin_messages.order(:created_at).map do |message|
        {
          id: message.id,
          role: message.role,
          content: message.content,
          created_at: message.created_at
        }
      end

      # Return in the format expected by frontend
      render json: {
        id: @conversation.id,
        title: @conversation.title,
        active: @conversation.active,
        created_at: @conversation.created_at,
        updated_at: @conversation.updated_at,
        messages: formatted_messages,
        conversation_history: formatted_messages # Include both for compatibility
      }
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
    # Basic data structures for potential visualizations

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
        # Create a visualization action for the forecast data
        processed_actions << {
          type: "update_chart",
          chart_id: "forecast_chart",
          data: action["data"],
          links: action["links"]
        }

        # Save forecast if it's not just a temporary visualization
        if action["data"]["forecast"].present? && action["data"]["forecast"].size > 5
          forecast = save_forecast(action["data"])
          processed_actions << { type: "notification", message: "Forecast created successfully" } if forecast
        end

      when "show_trends"
        # Process trend data for display
        processed_actions << {
          type: "update_chart",
          chart_id: "trends_chart",
          data: action["data"],
          links: action["links"]
        }

      when "show_budget"
        # Process budget data for display
        processed_actions << {
          type: "update_chart",
          chart_id: "budget_chart",
          data: action["data"],
          links: action["links"]
        }

      when "show_categories"
        # Create a chart for category breakdown
        processed_actions << {
          type: "update_chart",
          chart_id: "category_chart",
          data: {
            labels: action["data"]["category_breakdown"].keys,
            series: action["data"]["category_breakdown"].values.map(&:abs)
          },
          links: action["links"]
        }

      when "show_anomalies"
        # Create a list of anomalous transactions
        processed_actions << {
          type: "show_data",
          data_type: "anomalies",
          data: action["data"]["anomalies"],
          links: action["links"]
        }

      when "show_data"
        # Generic data display action
        processed_actions << action

      when "link"
        # Direct link to another part of the application
        processed_actions << action
      else
        # type code here
      end
    end

    processed_actions
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

    forecast.save ? forecast : nil
  end
  end
end
