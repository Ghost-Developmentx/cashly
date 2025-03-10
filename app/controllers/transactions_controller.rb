class TransactionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_transaction, only: %i[show edit update destroy]

  def index
    @transactions = current_user.transactions.order(date: :desc).includes(:account, :category)
                                .page(params[:page])
                                .limit(20)
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
  end

  def destroy
  end
end
