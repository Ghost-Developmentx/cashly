class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :check_onboarding_status

  private

  def check_onboarding_status
    return unless user_signed_in?
    return if devise_controller?
    return if request.path.start_with?("/profile/onboarding")
    return if request.path.start_with?("/profile/complete_onboarding")

    redirect_to onboarding_profile_path if current_user.needs_onboarding?
  end
end
