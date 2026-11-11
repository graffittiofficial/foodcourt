module Admin
  class InvitationsController < BaseController
    def resend
      invitation = platform_invitations.outstanding.find(params[:id])
      invitation.resend!
      redirect_to admin_organizations_path, notice: "Invitation resent."
    end

    def destroy
      invitation = platform_invitations.find(params[:id])
      invitation.revoke!
      redirect_to admin_organizations_path, notice: "Invitation revoked."
    end

    private

    def platform_invitations
      Invitation.where(invited_by_admin_id: Current.account.id)
    end
  end
end
