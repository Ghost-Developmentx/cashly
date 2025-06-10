class PlaidConnectionForm
  include ActiveModel::Model

  attr_accessor :public_token, :metadata, :accounts

  validates :public_token, presence: true

  def initialize(attributes = {})
    super
    @metadata ||= {}
    @accounts ||= []
  end

  def institution_name
    metadata["institution"]&.dig("name") || "Unknown Institution"
  end

  def institution_id
    metadata["institution"]&.dig("institution_id") || "unknown"
  end

  def selected_account_ids
    accounts.map { |acc| acc["id"] }
  end
end
