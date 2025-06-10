module Fin
  class ConversationsController < ApplicationController
    def index
      conversation = current_user.fin_conversations.active.first ||
                     current_user.fin_conversations.order(created_at: :desc).first

      render_success(
        conversation: present_conversation(conversation),
        messages: conversation ? format_messages(conversation.fin_messages) : []
      )
    end

    def query
      result = FinancialAI::ProcessQuery.call(
        user: current_user,
        query: params[:query]
      )

      render_operation_result(result)
    end

    def show
      conversation = current_user.fin_conversations.find(params[:id])
      activate_conversation(conversation)

      render_success(
        present_conversation(conversation).merge(
          messages: format_messages(conversation.fin_messages),
          conversation_history: format_messages(conversation.fin_messages)
        )
      )
    end

    def clear
      result = FinancialAI::ClearConversation.call(user: current_user)
      render_operation_result(result)
    end

    def history
      result = FinancialAI::GetConversationHistory.call(user: current_user)
      render_operation_result(result)
    end

    def feedback
      result = FinancialAI::RecordFeedback.call(
        user: current_user,
        message_id: params[:message_id],
        feedback_type: params[:feedback],
        rating: params[:rating]
      )

      render_operation_result(result)
    end

    private

    def present_conversation(conversation)
      return {} unless conversation

      {
        id: conversation.id,
        title: conversation.title,
        active: conversation.active,
        created_at: conversation.created_at,
        updated_at: conversation.updated_at
      }
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

    def activate_conversation(conversation)
      current_user.fin_conversations.update_all(active: false)
      conversation.update(active: true)
    end
  end
end
