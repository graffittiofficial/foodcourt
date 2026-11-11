class InvitationsController < ApplicationController
  allow_unauthenticated_access
  before_action :resume_session
  before_action :set_invitation

  def show
    return render_expired unless @invitation.active?

    @existing_user = User.find_by(email_address: @invitation.email_address)
    if @existing_user&.driver?
      return redirect_to root_path, alert: "Driver accounts cannot accept Restaurant management invitations."
    end
    if Current.account.present? && Current.account != @existing_user
      return redirect_to new_session_path, alert: "Sign in with the invited email address to accept this invitation."
    end
    if @existing_user && Current.account.nil?
      session[:return_to_after_authenticating] = invitation_url(token: params[:token])
      return redirect_to new_session_path, notice: "Sign in with the invited email address to accept this invitation."
    end
    if AdminAccount.exists?(email_address: @invitation.email_address)
      return redirect_to root_path, alert: "This email address belongs to a platform admin and cannot receive a User invitation."
    end
  end

  def create
    return render_expired unless @invitation.active?

    existing_user = User.find_by(email_address: @invitation.email_address)
    if existing_user && Current.account != existing_user
      session[:return_to_after_authenticating] = invitation_url(token: params[:token])
      return redirect_to new_session_path, alert: "Sign in with the invited email address to accept this invitation."
    end
    if !existing_user && Current.account.present?
      return redirect_to root_path, alert: "Sign out before accepting an invitation for a different email address."
    end
    if AdminAccount.exists?(email_address: @invitation.email_address)
      return redirect_to root_path, alert: "This email address belongs to a platform admin and cannot receive a User invitation."
    end

    @user = @invitation.accept!(
      user: existing_user,
      name: params.dig(:user, :name),
      password: params.dig(:user, :password),
      password_confirmation: params.dig(:user, :password_confirmation)
    )
    start_new_session_for(@user) unless existing_user
    redirect_to after_authentication_url, notice: "Invitation accepted."
  rescue ActiveRecord::RecordInvalid => error
    @user = error.record
    @existing_user = existing_user
    render :show, status: :unprocessable_entity
  end

  private

  def set_invitation
    digest = Digest::SHA256.hexdigest(params[:token].to_s)
    @invitation = Invitation.find_by!(token_digest: digest)
  end

  def render_expired
    render :expired, status: :gone
  end
end
