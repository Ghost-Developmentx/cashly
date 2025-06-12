class ApplicationQuery
  include ActiveModel::Model

  def self.call(**args)
    new(**args).call
  end

  def call
    execute
  end

  protected

  def execute
    raise NotImplementedError, "#{self.class} must implement #execute"
  end

  # Common query helpers
  def paginate(scope, page: 1, per_page: 20)
    scope.page(page).per(per_page)
  end

  def recent_first(scope, column = :created_at)
    scope.order(column => :desc)
  end

  def by_date_range(scope, start_date, end_date, column = :created_at)
    scope = scope.where("#{column} >= ?", start_date) if start_date
    scope = scope.where("#{column} <= ?", end_date) if end_date
    scope
  end
end