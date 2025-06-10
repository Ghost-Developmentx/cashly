module Banking
  class CreatePlaidLinkToken < BaseOperation
    attr_reader :user

    validates :user, presence: true

    def initialize(user:)
      @user = user
    end

    def execute
      plaid_service = PlaidService.new(user)
      link_token = plaid_service.create_link_token

      if link_token.present?
        success(
          link_token: link_token,
          message: "Link token created successfully"
        )
      else
        failure("Failed to create Plaid link token")
      end
    rescue Plaid::ApiError => e
      Rails.logger.error "Plaid link token error: #{e.message}"
      failure("Unable to create bank connection link: #{e.message}")
    end
  end
end
