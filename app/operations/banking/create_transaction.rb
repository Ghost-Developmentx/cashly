module Banking
  class CreateTransaction < BaseOperation
    attr_reader :user, :form

    validates :user, presence: true

    def initialize(user:, params:)
      @user = user
      @form = TransactionForm.new(params)
    end

    def execute
      validate_form!

      account = find_or_validate_account
      category = find_or_create_category

      transaction = create_transaction(account, category)

      # Auto-categorize if needed
      if transaction.category_id.blank? && transaction.description.present?
        categorize_transaction(transaction)
      end

      success(
        transaction: present_transaction(transaction),
        message: "Transaction created successfully"
      )
    end

    private

    def validate_form!
      unless form.valid?
        raise ActiveRecord::RecordInvalid.new(form)
      end
    end

    def find_or_validate_account
      if form.account_id.present?
        user.accounts.find(form.account_id)
      elsif form.account_name.present?
        account = user.accounts.where("name ILIKE ?", "%#{form.account_name}%").first
        raise ActiveRecord::RecordNotFound, "Account not found" unless account
        account
      else
        raise StandardError, "Account must be specified"
      end
    end

    def find_or_create_category
      return nil unless form.category_name.present? || form.category_id.present?

      if form.category_id.present?
        Category.find(form.category_id)
      elsif form.category_name.present?
        Category.find_or_create_by(name: form.category_name)
      end
    end

    def create_transaction(account, category)
      attributes = form.to_transaction_attributes
      attributes[:category] = category if category

      account.transactions.create!(attributes)
    end

    def categorize_transaction(transaction)
      CategorizeTransactionJob.perform_later(transaction.id)
    end

    def present_transaction(transaction)
      Banking::TransactionPresenter.new(transaction).as_json
    end
  end
end
