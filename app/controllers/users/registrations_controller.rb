class Users::RegistrationsController < Devise::RegistrationsController
  def create
    super do |resource|
      if resource.persisted?
        UserMailer.welcome_email(resource).deliver_later
      end
    end
  end

  protected

  def after_sign_up_path_for(resource)
    "/profile/onboarding"
  end

  def after_inactive_sign_up_path_for(resource)
    "/profile/onboarding"
  end
end
