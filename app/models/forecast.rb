class Forecast < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :time_horizon, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :result_data, presence: true, on: :update

  serialize :included_category_ids, coder: JSON

  def included_categories
    return [] if included_category_ids.blank?
    Category.where(id: included_category_ids)
  end

  def exclude_categories?(categories)
    return false if included_category_ids.blank?
    Array(categories).any? do |category|
      !included_category_ids.include?(category.id.to_s)
    end
  end

  # For displaying the forecast date range
  def date_range
    start_date = created_at || Date.today
    end_date = start_date + time_horizon.days
    "#{start_date.strftime('%b %d, %Y')} - #{end_date.strftime('%b %d, %Y')}"
  end
end
