class OnboardingHelperJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    # Check if onboarding was completed
    if !user.onboarding_completed? && user.created_at < 1.day.ago
      # Send reminder email if onboarding not completed after 24hrs
      UserMailer.profile_completion_reminder(user).deliver_now
    elsif user.onboarding_completed? && user.accounts.none? && user.created_at < 2.days.ago
      # If onboarding completed but no accounts connected after 48 hours
      UserMailer.account_connection_reminder(user).deliver_now
    end
  end
end
