class BaseOperation
  include ActiveModel::Model

  def self.call(**args)
    new(**args).call
  end

  def call
    return failure(errors.full_messages.join(', ')) unless valid?

    ActiveRecord::Base.transaction do
      execute
    end
  rescue StandardError => e
    handle_error(e)
  end

  protected

  def execute
    raise NotImplementedError, "#{self.class} must implement #execute"
  end

  def success(data = {}, status: :ok)
    Result.new(success: true, data: data, status: status)
  end

  def failure(error, status: :unprocessable_entity)
    Result.new(success: false, error: error, status: status)
  end

  def handle_error(error)
    Rails.logger.error "[#{self.class}] Error: #{error.message}"
    Rails.logger.error error.backtrace.first(10).join("\n")
    failure("An error occurred: #{error.message}", :internal_server_error)
  end
end
