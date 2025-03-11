class CategoriesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_category, only: %i[show edit update destroy]

  def index
    @categories = Category.all.order(name: :asc)
  end

  def show
    # Find transactions with this category
    @transactions = Transaction.joins(:account)
                               .where(category: @category, accounts: { user_id: current_user.id })
                               .order(date: :desc)
                               .page(params[:page])
                               .per(20)

    # Calculate total spending in this category
    @total_spent = @transactions.where("amount < 0").sum(:amount).abs

    # Calculate monthly average spending
    first_transaction = @transactions.where("amount < 0").order(date: :asc).first
    if first_transaction
      months_count = (Date.today.year * 12 + Date.today.month) -
        (first_transaction.date.year * 12 + first_transaction.date.month) + 1
      @monthly_average = months_count > 0 ? @total_spent / months_count : @total_spent
    else
      @monthly_average = 0
    end
    # Get related budget if it exists
    @budget = current_user.budgets.find_by(category: @category)
  end

  def new
    @category = Category.new
    @parent_categories = Category.where(parent_category_id: nil)
  end

  def edit
    @parent_categories = Category.where(parent_category_id: nil).where.not(id: @category.id)
  end

  def create
    @category = Category.new(category_params)

    respond_to do |format|
      if @category.save
        format.html { redirect_to @category, notice: "Category was successfully created." }
        format.json { render :show, status: :created, location: @category }
      else
        @parent_categories = Category.where(parent_category_id: nil)
        format.html { render :new }
        format.json { render json: @category.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if @category.update(category_params)
        format.html { redirect_to @category, notice: "Category was successfully updated." }
        format.json { render :show, status: :ok, location: @category }
      else
        @parent_categories = Category.where(parent_category_id: nil).where.not(id: @category.id)
        format.html { render :edit }
        format.json { render json: @category.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    # Check if category has transactions or budgets before destroying
    if Transaction.where(category: @category).exists?
      redirect_to categories_url, alert: "Cannot delete category with transactions. Reassign transactions first."
    elsif Budget.where(category: @category).exists?
      redirect_to categories_url, alert: "Cannot delete category with budget. Remove budgets first"
    else
      @category.destroy
      respond_to do |format|
        format.html { redirect_to categories_url, notice: "Category was successfully destroyed." }
        format.json { head :no_content }
      end
    end
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.expect(category: [ :name, :description, :parent_category_id ])
  end
end
