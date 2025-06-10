module ApiResponses
  extend ActiveSupport::Concern

  def render_success(data = {}, message: nil, status: :ok)
    response = { success: true }
    response[:data] = data if data.present?
    response[:message] = message if message.present?

    render json: response, status: status
  end

  def render_error(error, status: :unprocessable_entity)
    render json: {
      success: false,
      error: error
    }, status: status
  end

  def render_operation_result(result)
    if result.success?
      render_success(result.data, status: result.status)
    else
      render_error(result.error, status: result.status)
    end
  end
end
