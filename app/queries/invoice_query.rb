class InvoiceQuery
  def initialize(relation = Invoice.all)
    @relation = relation
  end

  def with_filters(filters)
    return self if filters.blank?

    by_status(filters[:status])
    by_client_name(filters[:client_name])
    by_days(filters[:days])
    by_limit(filters[:limit])

    self
  end

  def execute
    @relation.order(created_at: :desc)
  end

  private

  def by_status(status)
    return unless status.present?
    @relation = @relation.where(status: status)
  end

  def by_client_name(name)
    return unless name.present?
    @relation = @relation.where("client_name ILIKE ?", "%#{name}%")
  end

  def by_days(days)
    return unless days.present?
    @relation = @relation.where("created_at >= ?", days.to_i.days.ago)
  end

  def by_limit(limit)
    limit = limit.present? ? limit.to_i : 20
    @relation = @relation.limit(limit)
  end
end
