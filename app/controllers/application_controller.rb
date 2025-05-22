class ApplicationController < ActionController::API
  include Clerk::Authenticatable

  before_action :require_clerk_session!
  helper_method :current_user

  private

  def require_clerk_session!
    unless clerk&.session_token
      head :unauthorized
    end
  end

def current_user
  return @current_user if defined?(@current_user)

  if clerk&.user
    email_address = clerk.user.email_addresses&.first&.email_address

    @current_user = User.find_or_initialize_by(clerk_id: clerk.user.id)
    @current_user.email = email_address
    @current_user.first_name = clerk.user.first_name
    @current_user.last_name = clerk.user.last_name

    unless @current_user.persisted?
      begin
        @current_user.save!
        Rails.logger.info "✅ Created user #{email_address} with clerk_id #{clerk.user.id}"
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "❌ Failed to save user: #{e.record.errors.full_messages.join(', ')}"
        head :unprocessable_entity and return
      end
    end
  end

  @current_user
end
end
