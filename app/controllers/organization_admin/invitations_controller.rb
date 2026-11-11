module OrganizationAdmin
  class InvitationsController < BaseController
    def resend
      invitation = current_organization.invitations.outstanding.find(params[:id])
      invitation.resend!
      redirect_back fallback_location: organization_admin_root_path, notice: "Invitation resent."
    end

    def destroy
      invitation = current_organization.invitations.find(params[:id])
      invitation.revoke!
      redirect_back fallback_location: organization_admin_root_path, notice: "Invitation revoked."
    end
  end
end
