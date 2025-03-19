class ProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def show
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to profile_path, notice: "Profile was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def onboarding
  end

  def complete_onboarding
    if @user.update(user_params.merge(onboarding_completed: true))
      redirect_to dashboard_path, notice: "Welcome to Cashly! Your profile is now complete!"
    else
      render :onboarding, status: :unprocessable_content
    end
  end

  def complete_tutorial
    if @user.update(tutorial_completed: true)
      render json: { success: true }
    else
      render json: { success: false }, status: :unprocessable_content
    end
  end

  private

  def set_user
    @user = current_user
  end

  def user_params
    params.expect(user: [ :first_name, :last_name, :phone_number, :timezone,
                         :company_name, :company_size, :industry, :business_type,
                         :currency, :fiscal_year_start,
                         :address_line1, :address_line2, :city, :state, :zip_code, :country ])
  end
end
