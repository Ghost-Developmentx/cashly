class MeController < ApplicationController
  def show
    render json: {
      id: current_user.id,
      email: current_user.email,
      name: "#{current_user.first_name} #{current_user.last_name}"
    }
  end
end
