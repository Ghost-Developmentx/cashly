class TransactionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_transaction, only: %i[show edit update destroy]

  def index
    @transactions = current_user.transactions.order(date: :desc).includes(:account, :category)
                                .page(params[:page])
                                .per(20)
  end

  def show
  end

  def new
    @transaction = Transaction.new
    @accounts = current_user.accounts
    @categories = Category.all
  end

  def edit
    @accounts = current_user.accounts
    @categories = Category.all
  end

  def create
    @transaction = Transaction.new(transaction_params)

    if @transaction.category_id.blank? && @transaction.description.present?
      category_response = AiService.categorize_transaction(
      @transaction.description,
      @transaction.amount,
      @transaction.date
      )

      if category_response.is_a?(Hash) && !category_response[:error]
        category_name = category_response["category"]
        category = Category.find_or_create_by(name: category_name)
        @transaction.category = category
      end
    end

    respond_to do |format|
      if @transaction.save
        format.html { redirect_to @transaction, notice: "Transaction was successfully created." }
        format.json { render :show, status: :created, location: @transaction }
      else
        @accounts = current_user.accounts
        @categories = Category.all
        format.html { render :new }
        format.json { render json: @transaction.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if @transaction.update(transaction_params)
        format.html { redirect_to @transaction, notice: "Transaction was successfully updated." }
        format.json { render :show, status: :ok, location: @transaction }
      else
        @accounts = current_user.accounts
        @categories = Category.all
        format.html { render :edit }
        format.json { render json: @transaction.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @transaction.destroy
    respond_to do |format|
      format.html { redirect_to transactions_url, notice: "Transaction was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def reconcile
    @transaction = Transaction.find(params[:transaction_id])
    @bank_statement = BankStatement.find(params[:bank_statement_id])

    if @transaction.reconcile(@bank_statement.id)
      # Get updated data for the view
      @reconciled_transactions = @bank_statement.transactions.where(reconciled: true)
      @available_transactions = @bank_statement.account.transactions
                                               .where(date: @bank_statement.start_date..@bank_statement.end_date)
                                               .where(reconciled: false)

      respond_to do |format|
        format.turbo_stream
        format.json { render json: { success: true, transaction: @transaction } }
      end
    else
      respond_to do |format|
        format.turbo_stream
        format.json { render json: { success: false, errors: @transaction.errors.full_messages } }
      end
    end
  end

  def unreconcile
    @transaction = Transaction.find(params[:id])
    @bank_statement = @transaction.bank_statement

    if @transaction.unreconcile
      # Get updated data for the view
      @reconciled_transactions = @bank_statement.transactions.where(reconciled: true)
      @available_transactions = @bank_statement.account.transactions
                                               .where(date: @bank_statement.start_date..@bank_statement.end_date)
                                               .where(reconciled: false)

      respond_to do |format|
        format.turbo_stream
        format.json { render json: { success: true, transaction: @transaction } }
      end
    else
      respond_to do |format|
        format.turbo_stream
        format.json { render json: { success: false, errors: @transaction.errors.full_messages } }
      end
    end
  end

  private

  def set_transaction
    @transaction = current_user.transactions.find(params[:id])
  end

  def transaction_params
    params.expect(transaction: [ :account_id, :amount, :date, :description, :category_id, :recurring ])
  end
end
