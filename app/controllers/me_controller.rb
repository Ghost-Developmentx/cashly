class MeController < ApplicationController
  def show
    render json: {
      id: current_user.id,
      email: current_user.email,
      name: "#{current_user.first_name} #{current_user.last_name}",
      first_name: current_user.first_name,
      last_name: current_user.last_name,
      currency: current_user.currency,
      timezone: current_user.timezone,
      date_format: current_user.date_format,
      theme: current_user.theme,
      language: current_user.language,
      notification_settings: current_user.notification_settings
    }
  end

  def update
    if current_user.update(user_params)
      render json: {
        success: true,
        message: "Settings updated successfully",
        user: {
          id: current_user.id,
          email: current_user.email,
          name: "#{current_user.first_name} #{current_user.last_name}",
          currency: current_user.currency,
          timezone: current_user.timezone,
          date_format: current_user.date_format,
          theme: current_user.theme,
          language: current_user.language,
          notification_settings: current_user.notification_settings
        }
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
      :currency, :timezone, :date_format, :theme, :language,
      notification_settings: {}
    )
  end
end
