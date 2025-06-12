module RequestMonitoring
  extend ActiveSupport::Concern

  included do
    around_action :monitor_request
  end

  private

  def monitor_request
    start_time = Time.current

    yield

    duration = ((Time.current - start_time) * 1000).round(2) # in milliseconds

    ApplicationMonitor.track_api_request(
      controller_name,
      action_name,
      current_user&.id,
      duration,
      response.status
    )
  rescue => e
    duration = ((Time.current - start_time) * 1000).round(2)

    ApplicationMonitor.track_api_request(
      controller_name,
      action_name,
      current_user&.id,
      duration,
      500
    )

    raise e
  end
end
