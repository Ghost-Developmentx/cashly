class StripeConnectSetupForm
  include ActiveModel::Model

  attr_accessor :business_type, :country

  validates :business_type, presence: true, inclusion: { in: %w[individual company] }
  validates :country, presence: true, inclusion: { in: %w[US CA GB AU] }

  def initialize(attributes = {})
    super
    @business_type ||= "individual"
    @country ||= "US"
  end

  def to_stripe_params
    {
      type: "express",
      country: country,
      business_type: business_type,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true }
      },
      settings: {
        payouts: {
          schedule: {
            interval: "daily"
          }
        }
      }
    }
  end
end
