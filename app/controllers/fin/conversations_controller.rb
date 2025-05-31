module Fin
  class ConversationsController < ApplicationController
    before_action :set_conversation, only: [:query]

    def index
      @conversation = current_user.fin_conversations.active.first ||
                      current_user.fin_conversations.order(created_at: :desc).first

      render json: {
        conversation: @conversation,
        messages: format_messages(@conversation&.fin_messages)
      }
    end

    def query
      query_text = params[:query]
      Rails.logger.info "🎯 [Controller] Received query: #{query_text}"

      # Add a user message
      @conversation.add_message("user", query_text)

      # Get recent conversation history for context
      recent_messages = @conversation.fin_messages
                                     .order(created_at: :desc)
                                     .limit(10)
                                     .reverse
                                     .map { |msg| { role: msg.role, content: msg.content } }

      Rails.logger.info "📝 Including #{recent_messages.length} messages in conversation history"

      # Process query with conversation history
      response = FinService.new(current_user).process_query(
        query_text,
        recent_messages  # Pass the recent messages
      )

      # Handle errors
      if response[:error].present?
        handle_error_response(response[:error])
        return
      end

      # Add assistant response
      response_text = extract_response_text(response)
      assistant_message = @conversation.add_message("assistant", response_text)

      # Update conversation metadata
      update_conversation_metadata(query_text)

      # Record tool usage
      if response["tool_results"].present?
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

      # Send a response with actions and full conversation history
      render json: {
        message: response_text,
        actions: response["actions"] || [],
        conversation_history: @conversation.conversation_history,
        conversation_id: @conversation.id
      }
    end

    def show
      @conversation = current_user.fin_conversations.find(params[:id])
      activate_conversation(@conversation)

      render json: {
        id: @conversation.id,
        title: @conversation.title,
        active: @conversation.active,
        created_at: @conversation.created_at,
        updated_at: @conversation.updated_at,
        messages: format_messages(@conversation.fin_messages),
        conversation_history: format_messages(@conversation.fin_messages)
      }
    end

    def clear
      current_user.fin_conversations.where(active: true).update_all(active: false)
      render json: { success: true, message: "Started a new conversation." }
    end

    def history
      conversations = current_user.fin_conversations.order(created_at: :desc)
      render json: conversations.as_json(only: [:id, :title, :created_at, :updated_at, :active])
    end

    def feedback
      message = find_message_for_feedback(params[:message_id])

      if message
        update_message_feedback(message, params[:feedback], params[:rating])
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

    def process_fin_query(query_text)
      FinService.new(current_user).process_query(
        query_text,
        @conversation.conversation_history
      )
    end

    def handle_error_response(error)
      Rails.logger.error "FinService error: #{error}"
      render json: {
        error: error,
        message: "I'm having trouble processing your request right now. Please try again."
      }, status: :unprocessable_entity
    end

    def extract_response_text(response)
      response["response_text"] || response[:response_text] || "I'm not sure how to respond to that."
    end

    def update_conversation_metadata(query_text)
      if @conversation.title.blank? && @conversation.fin_messages.count == 2
        @conversation.update(title: query_text.truncate(50))
      end
    end

    def record_tool_usage(tool_results)
      assistant_message = @conversation.fin_messages
                                       .where(role: "assistant")
                                       .order(created_at: :desc)
                                       .first

      return if assistant_message&.tools_used.present?

      assistant_message&.update(
        tools_used: tool_results.map do |result|
          {
            name: result["tool"],
            success: !result["result"].key?("error"),
            timestamp: Time.current
          }
        end
      )
    end

    def activate_conversation(conversation)
      conversation.update(active: true)
      current_user.fin_conversations.where.not(id: conversation.id).update_all(active: false)
    end

    def format_messages(messages)
      return [] unless messages

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
      message.update(
        feedback_rating: rating,
        feedback_text: feedback_type,
        was_helpful: feedback_type == "helpful"
      )
    end
  end
end
