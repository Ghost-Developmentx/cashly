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

    def query
      query_text = params[:query]

      Rails.logger.info "🎯 [Controller] Received query: #{query_text}"

      # Add a user message to conversation
      @conversation.add_message("user", query_text)

      # Process query using the new service
      response = FinService.process_query(
        current_user.id,
        query_text,
        @conversation.conversation_history
      )

      Rails.logger.info "📤 [Controller] FinService response keys: #{response.keys}"

      # Check for errors
      if response[:error].present?
        Rails.logger.error "FinService error: #{response[:error]}"
        render json: {
          error: response[:error],
          message: "I'm having trouble processing your request right now. Please try again."
        }, status: :unprocessable_content
        return
      end

      # Ensure we have a response_text
      response_text = response["response_text"] || response[:response_text] || "I'm not sure how to respond to that."

      # Add assistant response to conversation
      @conversation.add_message("assistant", response_text)

      # Update the conversation title if this is the first exchange
      update_conversation_title_if_needed(query_text)

      # Record tool usage for learning
      record_tool_usage_if_present(response)

      # Prepare a final response
      final_response = {
        message: response_text,
        actions: response["actions"] || [],
        conversation_history: @conversation.conversation_history
      }

      Rails.logger.info "🚀 [Controller] Sending response with #{final_response[:actions]&.length || 0} actions"

      render json: final_response
    end

    def clear
      current_user.fin_conversations.where(active: true).update_all(active: false)
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

      formatted_messages = format_messages_for_response(@conversation.fin_messages)

      render json: {
        id: @conversation.id,
        title: @conversation.title,
        active: @conversation.active,
        created_at: @conversation.created_at,
        updated_at: @conversation.updated_at,
        messages: formatted_messages,
        conversation_history: formatted_messages
      }
    end

    def feedback
      message_id = params[:message_id]
      feedback_type = params[:feedback]
      rating = params[:rating]

      message = find_message_for_feedback(message_id)

      if message
        update_message_feedback(message, feedback_type, rating)
        render json: { success: true }
      else
        render json: { success: false, error: "Message not found" }, status: :not_found
      end
    end


    private

    def set_conversation
      @conversation = current_user.fin_conversations.where(active: true).first
      @conversation ||= current_user.fin_conversations.create(active: true)
    end

    def update_conversation_title_if_needed(query_text)
      if @conversation.title.blank? && @conversation.fin_messages.count == 2
        @conversation.update(title: query_text.truncate(50))
      end
    end

    def record_tool_usage_if_present(response)
      return unless response["tool_results"].present?

      assistant_message = @conversation.fin_messages.where(role: "assistant").order(created_at: :desc).first
      return unless assistant_message

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

    def format_messages_for_response(messages)
      messages.order(:created_at).map do |message|
        {
          id: message.id,
          role: message.role,
          content: message.content,
          created_at: message.created_at
        }
      end
    end

    def find_message_for_feedback(message_id)
      if message_id.start_with?("temp-")
        conversation = current_user.fin_conversations.where(active: true).first
        conversation&.fin_messages&.where(role: "assistant")&.order(created_at: :desc)&.first
      else
        FinMessage.find_by(id: message_id)
      end
    end

    def update_message_feedback(message, feedback_type, rating)
      was_helpful = feedback_type == "helpful"

      message.update(
        feedback_rating: rating,
        feedback_text: feedback_type,
        was_helpful: was_helpful
      )
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

      when "show_transactions"
        # Process transaction data for display
        processed_actions << {
          type: "show_transactions",
          data_type: "transactions",
          data: action["data"],
          links: action["links"]
        }

      when "connect_stripe"
        processed_actions << {
          type: "connect_stripe",
          data: action["data"]
        }

      when "show_invoices"
        processed_actions << {
          type: "show_invoices",
          data: action["data"],
          links: action["links"]
        }

      when "invoice_created", "invoice_marked_paid"
        processed_actions << {
          type: action["type"],
          data: action["data"],
          message: action["message"]
        }

        # Also show an updated invoice list
        if action["data"]["invoice"]
          invoices = FinService.fetch_user_invoices(current_user.id)
          processed_actions << {
            type: "show_invoices",
            data: {
              invoices: FinService.format_invoices_for_display(invoices)
            }
          }
        end

      when "reminder_sent"
        processed_actions << {
          type: "notification",
          message: action["message"]
        }

      when "show_accounts"
        # Process transaction data for display
        processed_actions << {
          type: "show_accounts",
          data_type: "accounts",
          data: action["data"],
          links: action["links"]
        }

      when "setup_stripe_connect"
        processed_actions << {
          type: "setup_stripe_connect",
          data: action["data"],
          message: action["message"] || "Let's set up Stripe Connect to accept payments"
        }

      when "show_stripe_connect_status"
        processed_actions << {
          type: "show_stripe_connect_status",
          data: action["data"],
          message: action["message"] || "Here's your Stripe Connect status"
        }

      when "stripe_connect_already_setup"
        processed_actions << {
          type: "stripe_connect_already_setup",
          data: action["data"],
          message: action["message"] || "Your Stripe Connect is already set up!"
        }

      when "open_stripe_dashboard"
        processed_actions << {
          type: "open_stripe_dashboard",
          data: action["data"],
          message: action["message"] || "Opening your Stripe dashboard..."
        }

      when "stripe_connect_error"
        processed_actions << {
          type: "stripe_connect_error",
          error: action["error"],
          message: action["message"] || "There was an error with Stripe Connect"
        }

      when "show_stripe_connect_earnings"
        processed_actions << {
          type: "show_stripe_connect_earnings",
          data: action["data"],
          links: action["links"]
        }

      when "stripe_connect_disconnected"
        processed_actions << {
          type: "stripe_connect_disconnected",
          message: action["message"] || "Stripe Connect has been disconnected"
        }


      when "link"
        # Direct link to another part of the application
        processed_actions << action

      when "initiate_plaid_connection"
        processed_actions << {
          type: "initiate_plaid_connection",
          action: action["action"] || "initiate_plaid_connection",
          data: action["data"] || {},
          user_id: action["user_id"]
        }      else
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
