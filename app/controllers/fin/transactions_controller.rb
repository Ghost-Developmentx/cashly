module Fin
  class TransactionsController < ApplicationController
    def index
      result = Banking::ListTransactions.call(
        user: current_user,
        filters: filter_params
      )

      render_operation_result(result)
    end

    def create
      result = Banking::CreateTransaction.call(
        user: current_user,
        params: transaction_params
      )

      render_operation_result(result)
    end

    def update
      result = Banking::UpdateTransaction.call(
        user: current_user,
        transaction_id: params[:id],
        params: transaction_params
      )

      render_operation_result(result)
    end

    def destroy
      result = Banking::DeleteTransaction.call(
        user: current_user,
        transaction_id: params[:id]
      )

      render_operation_result(result)
    end

    def show
      transaction = current_user.transactions.find(params[:id])
      render_success(
        transaction: Banking::TransactionPresenter.new(transaction).as_json(include_account: true)
      )
    end

    def categorize_bulk
      result = Banking::CategorizeTransactions.call(
        user: current_user,
        transaction_ids: params[:transaction_ids]
      )

      render_operation_result(result)
    end

    private

    def transaction_params
      params.require(:transaction).permit(
        :account_id, :account_name, :amount, :date, :description,
        :category_id, :category_name, :recurring, :notes
      )
    end

    def filter_params
      params.permit(
        :account_id, :account_name, :days, :start_date, :end_date,
        :category, :min_amount, :max_amount, :type, :limit
      )
    end
  end
end
