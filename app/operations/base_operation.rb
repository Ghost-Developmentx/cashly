# app/operations/base_operation.rb
class BaseOperation
  include ActiveModel::Model

  def self.call(**args)
    new(**args).call
  end

  def call
    start_time = Time.current

    return failure(errors.full_messages.join(', ')) unless valid?

    result = ActiveRecord::Base.transaction do
      execute
    end

    # Track successful operation
    duration = ((Time.current - start_time) * 1000).round(2)
    ApplicationMonitor.track_operation(
      self.class,
      user_id,
      true,
      duration
    )

    result
  rescue StandardError => e
    # Track failed operation
    duration = ((Time.current - start_time) * 1000).round(2)
    ApplicationMonitor.track_operation(
      self.class,
      user_id,
      false,
      duration,
      e.message
    )

    handle_error(e)
  end

  protected

  def execute
    raise NotImplementedError, "#{self.class} must implement #execute"
  end

  def success(data = {})
    data = data.is_a?(Hash) ? data : {}
    Result.new(success: true, data: data, status: :ok)
  end

  def failure(error, status = :unprocessable_entity)
    Result.new(success: false, error: error, status: status)
  end

  def handle_error(error)
    Rails.logger.error "[#{self.class}] Error: #{error.message}"
    Rails.logger.error error.backtrace.first(10).join("\n")
    failure("An error occurred: #{error.message}", :internal_server_error)
  end

  private

  # Override in operations that have a user
  def user_id
    @user&.id if defined?(@user)
  end
end
