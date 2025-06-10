module ErrorHandler
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :not_found
    rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
    rescue_from ActionController::ParameterMissing, with: :bad_request

    if defined?(Stripe)
      rescue_from Stripe::StripeError, with: :stripe_error
    end

    if defined?(Plaid)
      rescue_from Plaid::ApiError, with: :plaid_error
    end
  end

  private

  def not_found(error)
    render_error("Resource not found", status: :not_found)
  end

  def unprocessable_entity(error)
    render_error(error.record.errors.full_messages.join(", "), status: :unprocessable_entity)
  end

  def bad_request(error)
    render_error(error.message, status: :bad_request)
  end

  def stripe_error(error)
    Rails.logger.error "Stripe Error: #{error.message}"
    render_error("Payment processing error: #{error.message}", status: :payment_required)
  end

  def plaid_error(error)
    Rails.logger.error "Plaid Error: #{error.message}"
    render_error("Banking connection error", status: :bad_gateway)
  end
end
