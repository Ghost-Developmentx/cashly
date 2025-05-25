Rails.application.configure do
  # Set the Stripe API key globally
  Stripe.api_key = ENV["STRIPE_SECRET_KEY"]

  # Optional: Set API version for consistency
  Stripe.api_version = "2023-10-16"

  # Log configuration (remove in production)
  unless Rails.env.production?
    Rails.logger.info "Stripe configured with API key: #{ENV['STRIPE_SECRET_KEY'] ? 'SET' : 'MISSING'}"
  end
end
