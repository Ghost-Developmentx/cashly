class TransactionQuery
  def initialize(relation = Transaction.all)
    @relation = relation.includes(:account, :category)
  end

  def with_filters(filters)
    return self if filters.blank?

    by_account(filters[:account_id], filters[:account_name])
    by_date_range(filters[:start_date], filters[:end_date], filters[:days])
    by_category(filters[:category])
    by_amount_range(filters[:min_amount], filters[:max_amount])
    by_type(filters[:type])
    with_limit(filters[:limit])

    self
  end

  def execute
    @relation.order(date: :desc, created_at: :desc)
  end

  private

  def by_account(account_id, account_name)
    if account_id.present?
      @relation = @relation.where(account_id: account_id)
    elsif account_name.present?
      @relation = @relation.joins(:account)
                           .where("accounts.name ILIKE ?", "%#{account_name}%")
    end
  end

  def by_date_range(start_date, end_date, days)
    if start_date.present? && end_date.present?
      @relation = @relation.where(date: start_date..end_date)
    elsif days.present?
      @relation = @relation.where("date >= ?", days.to_i.days.ago.to_date)
    else
      # Default to last 30 days
      @relation = @relation.where("date >= ?", 30.days.ago.to_date)
    end
  end

  def by_category(category)
    return unless category.present?

    @relation = @relation.joins(:category)
                         .where("categories.name ILIKE ?", "%#{category}%")
  end

  def by_amount_range(min_amount, max_amount)
    if min_amount.present?
      @relation = @relation.where("ABS(amount) >= ?", min_amount.to_f)
    end

    if max_amount.present?
      @relation = @relation.where("ABS(amount) <= ?", max_amount.to_f)
    end
  end

  def by_type(type)
    case type
    when "income"
      @relation = @relation.where("amount > 0")
    when "expense"
      @relation = @relation.where("amount < 0")
    else
      # type code here
    end
  end

  def with_limit(limit)
    limit = [ limit.to_i, 100 ].min
    limit = 50 if limit <= 0
    @relation = @relation.limit(limit)
  end
end
