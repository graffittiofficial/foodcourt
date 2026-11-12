module OrganizationAdmin
  class BaseController < ApplicationController
    CHART_DATE_RANGES = { "7" => 7, "30" => 30, "90" => 90 }.freeze

    layout "organization_admin"

    before_action :require_organization_admin
    before_action :set_current_organization
    helper_method :current_organization

    private

    def require_organization_admin
      return if Current.user.is_a?(User) && Current.user.organization_admin?

      head :forbidden
    end

    def set_current_organization
      @current_organization = Current.user.administered_organizations.find_by(id: session[:organization_id])
      return Current.organization = @current_organization if @current_organization

      session.delete(:organization_id)
      redirect_to organizations_path
    end

    def current_organization
      Current.organization
    end

    def invite_user(role:, email_address:, restaurants: [])
      invitation = current_organization.invitations.new(
        role: role,
        email_address: email_address,
        invited_by_user: Current.user
      )
      restaurants.each { |restaurant| invitation.invitation_restaurants.build(restaurant: restaurant) }
      if invitation.save
        InvitationsMailer.invite(invitation, invitation.token).deliver_later
        invitation
      else
        invitation
      end
    end
  end
end
