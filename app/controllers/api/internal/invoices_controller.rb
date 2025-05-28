module Api
  module Internal
    class InvoicesController < ApplicationController
      skip_before_action :require_clerk_session!
      before_action :authenticate_internal_api

      def create
        user = User.find_by(id: params[:user_id])

        unless user
          render json: { error: "User not found" }, status: :not_found
          return
        end

        service = Fin::InvoiceService.new(user)
        result = service.create(invoice_params)

        if result[:success]
          render json: {
            success: true,
            invoice_id: result[:invoice_id],
            invoice: result[:invoice],
            platform_fee: result[:platform_fee],
            message: result[:message]
          }
        else
          render json: {
            success: false,
            error: result[:error]
          }, status: :unprocessable_entity
        end
      end

      def destroy
        invoice_id = params[:id]
        user_id = params[:user_id]

        Rails.logger.info "[Internal API] Delete request for invoice #{invoice_id} by user #{user_id}"

        @user = User.find_by(id: user_id)
        unless @user
          render json: { error: "User not found" }, status: :not_found
          return
        end

        service = Fin::InvoiceService.new(@user)
        result = service.send(:delete, invoice_id)

        Rails.logger.info "[Internal API] Delete result: #{result.inspect}"

        if result[:success]
          render json: {
            success: true,
            deleted_invoice: result[:deleted_invoice],
            stripe_deleted: result[:stripe_deleted],
            message: result[:message]
          }
        else
          render json: {
            success: false,
            error: result[:error]
          }, status: :unprocessable_entity
        end
      end

      private

      def authenticate_internal_api
        api_key = request.headers["X-Internal-Api-Key"]

        unless api_key == ENV["INTERNAL_API_KEY"]
          render json: { error: "Unauthorized" }, status: :unauthorized
        end
      end

      def invoice_params
        params.require(:invoice).permit(
          :client_name, :client_email, :amount,
          :description, :due_date, :currency
        )
      end
    end
  end
end
