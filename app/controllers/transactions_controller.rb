class TransactionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_transaction, only: %i[show edit update destroy update_category]
  before_action :set_accounts_and_categories, only: %i[index new edit]

  def index
    # Set up base query
    @transactions = current_user.transactions

    # Apply filters
    @transactions = @transactions.where(category_id: params[:category_id]) if params[:category_id].present?
    @transactions = @transactions.where(account_id: params[:account_id]) if params[:account_id].present?

    # Handle AI categorization filter
    if params[:ai_categorized].present?
      @transactions = @transactions.where(ai_categorized: params[:ai_categorized] == "true")
    end

    # Get final, paginated result
    @transactions = @transactions.order(date: :desc)
                                 .includes(:account, :category)
                                 .page(params[:page])
                                 .per(20)

    # Get count for banner display
    @uncategorized_count = current_user.transactions.where(category_id: nil).count
  end

  def show
  end

  def new
    @transaction = Transaction.new
  end

  def edit
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
        confidence = category_response["confidence"].to_f
        category = Category.find_or_create_by(name: category_name)

        @transaction.category = category
        @transaction.ai_categorized = true
        @transaction.categorization_confidence = confidence
      end
    end

    respond_to do |format|
      if @transaction.save
        format.html { redirect_to @transaction, notice: "Transaction was successfully created." }
        format.json { render :show, status: :created, location: @transaction }
      else
        set_accounts_and_categories
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
        set_accounts_and_categories
        format.html { render :edit }
        format.json { render json: @transaction.errors, status: :unprocessable_content }
      end
    end
  end

  def update_category
    original_category = @transaction.category
    new_category = Category.find(params[:category_id])

    if @transaction.update(category_id: params[:category_id])
      # Record feedback if this was an AI categorized transaction
      if @transaction.ai_categorized && original_category.present?
        CategoryFeedback.create(
          user: current_user,
          transaction_record: @transaction,
          suggested_category: original_category,
          chosen_category: new_category,
          feedback_type: "correction"
        )
      end

      respond_to do |format|
        format.html { redirect_to @transaction, notice: "Category was successfully updated." }
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @transaction, alert: "Failed to update category." }
        format.json { render json: { success: false, errors: @transaction.errors.full_messages } }
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

  def categorize_all
    # Get all uncategorized transactions
    uncategorized_count = current_user.transactions.where(category_id: nil).count

    if uncategorized_count > 0
      # Schedule background job
      CategorizeTransactionsJob.perform_later(current_user.id)

      respond_to do |format|
        format.html { redirect_to transactions_path, notice: "Categorizing #{uncategorized_count} transactions. This may take a few moments." }
        format.json { render json: { success: true, count: uncategorized_count } }
      end
    else
      respond_to do |format|
        format.html { redirect_to transactions_path, notice: "No uncategorized transactions found." }
        format.json { render json: { success: true, count: 0 } }
      end
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

  def category_feedback
    @transaction = Transaction.find(params[:transaction_id])
    feedback_type = params[:feedback_type]

    # Validate feedback type
    unless %w[confirmation needs_improvement correction].include?(feedback_type)
      redirect_to @transaction, alert: "Invalid feedback type."
      return
    end

    # Only process if the transaction was AI categorized
    if @transaction.ai_categorized && @transaction.category
      feedback = CategoryFeedback.new(
        user: current_user,
        transaction_record: @transaction,
        suggested_category: @transaction.category,
        chosen_category: @transaction.category, # Same for confirmation/needs_improvement
        feedback_type: feedback_type
      )

      if feedback.save
        redirect_to @transaction, notice: "Thank you for your feedback."
      else
        redirect_to @transaction, alert: "Could not save feedback: #{feedback.errors.full_messages.join(', ')}"
      end
    else
      redirect_to @transaction, alert: "Feedback can only be provided for AI-categorized transactions."
    end
  end

  private

  def set_transaction
    @transaction = current_user.transactions.find(params[:id])
  end

  def set_accounts_and_categories
    @accounts = current_user.accounts
    @categories = Category.all.order(:name)
  end

  def transaction_params
    params.require(:transaction).permit(:account_id, :amount, :date, :description, :category_id, :recurring)
  end
end
