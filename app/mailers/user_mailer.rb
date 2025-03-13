class UserMailer < ApplicationMailer
  default from: "notifications@cashly-app.com"

  def welcome_email(user)
    @user = user
    mail(to: @user.email, subject: "Welcome to Cashly!")
  end

  def profile_completion_reminder(user)
    @user = user
    mail(to: @user.email, subject: "Complete Your Cashly Profile")
  end

  def account_connection_reminder(user)
    @user = user
    mail(to: @user.email, subject: "Connect Your Bank Accounts To Cashly")
  end
end
