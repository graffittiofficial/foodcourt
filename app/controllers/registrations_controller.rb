class RegistrationsController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 5, within: 1.hour, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params.merge(role: :customer))
    if @user.name.blank?
      @user.errors.add(:name, "can't be blank")
      render :new, status: :unprocessable_entity
    elsif @user.save
      start_new_session_for(@user)
      redirect_to after_authentication_url, notice: "Your account has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
  end
end
