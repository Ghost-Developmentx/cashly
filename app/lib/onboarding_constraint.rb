class OnboardingConstraint
  def self.matches?(request)
    user = request.env["warden"].user(:user)
    return true unless user

    !user.needs_onboarding?
  end
end
