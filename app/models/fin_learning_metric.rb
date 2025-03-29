class FinLearningMetric < ApplicationRecord
  def self.helpfulness_trend(days = 30)
    # Calculate the trend in helpfulness over the specified period
    metrics = order(created_at: :desc).limit(days)

    # Skip if we don't have enough data
    return nil if metrics.count < 2

    # Calculate helpfulness rates
    rates = metrics.map do |metric|
      metric.helpful_messages.to_f / metric.feedback_messages
    end

    # Return the change from oldest to newest
    rates.last - rates.first
  end

  def self.tool_success_trend(days = 30)
    # Calculate the trend in tool success rate over the specified period
    metrics = order(created_at: :desc).limit(days)

    # Skip if we don't have enough data
    return nil if metrics.count < 2

    # Calculate tool success rates
    rates = metrics.map do |metric|
      metric.tools_success.to_f / metric.tools_used
    end

    # Return the change from oldest to newest
    rates.last - rates.first
  end
end
