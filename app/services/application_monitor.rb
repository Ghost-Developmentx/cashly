class ApplicationMonitor
  class << self
    def track_operation(operation_class, user_id, success, duration, error = nil)
      Rails.logger.info format_log_entry(
                          operation: operation_class.name,
                          user_id: user_id,
                          success: success,
                          duration: duration,
                          error: error
                        )
    end

    def track_api_request(controller, action, user_id, duration, status)
      Rails.logger.info format_log_entry(
                          controller: controller,
                          action: action,
                          user_id: user_id,
                          duration: duration,
                          status: status
                        )
    end

    def track_external_api_call(service, endpoint, duration, success)
      Rails.logger.info format_log_entry(
                          service: service,
                          endpoint: endpoint,
                          duration: duration,
                          success: success
                        )
    end

    private

    def format_log_entry(data)
      timestamp = Time.current.iso8601
      "[#{timestamp}] " + data.map { |k, v| "#{k}=#{v}" }.join(" ")
    end
  end
end
