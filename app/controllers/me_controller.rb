class MeController < ApplicationController
  def show
    render json: user_data
  end

  def update
    if current_user.update(user_params)
      # Mark onboarding as completed if all required fields are present
      if onboarding_complete?
        current_user.update(onboarding_completed: true)
      end

      render json: {
        success: true,
        message: "Profile updated successfully",
        user: user_data
      }
    else
      render json: {
        success: false,
        errors: current_user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.permit(
      :first_name, :last_name, :phone_number,
      :address_line1, :address_line2, :city, :state, :zip_code, :country,
      :company_name, :company_size, :industry, :business_type,
      :currency, :timezone, :date_format, :theme, :language,
      :onboarding_completed,
      notification_settings: {}
    )
  end

  def user_data
    {
      id: current_user.id,
      email: current_user.email,
      first_name: current_user.first_name,
      last_name: current_user.last_name,
      name: current_user.full_name,
      phone_number: current_user.phone_number,
      company_name: current_user.company_name,
      company_size: current_user.company_size,
      industry: current_user.industry,
      business_type: current_user.business_type,
      address: {
        line1: current_user.address_line1,
        line2: current_user.address_line2,
        city: current_user.city,
        state: current_user.state,
        zip_code: current_user.zip_code,
        country: current_user.country
      },
      settings: {
        currency: current_user.currency,
        timezone: current_user.timezone,
        date_format: current_user.date_format,
        theme: current_user.theme,
        language: current_user.language,
        notification_settings: current_user.notification_settings
      },
      onboarding_completed: current_user.onboarding_completed,
      tutorial_completed: current_user.tutorial_completed
    }
  end

  def onboarding_complete?
    current_user.first_name.present? &&
      current_user.last_name.present? &&
      current_user.company_name.present? &&
      current_user.industry.present?
  end
end
