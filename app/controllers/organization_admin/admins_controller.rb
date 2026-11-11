module OrganizationAdmin
  class AdminsController < BaseController
    def index
      load_admin_data
    end

    def create
      @invitation = invite_user(role: :organization_admin, email_address: params.dig(:admin, :email_address))
      if @invitation.persisted?
        redirect_to organization_admin_admins_path, notice: "Organization admin invitation sent."
      else
        load_admin_data
        render :index, status: :unprocessable_entity
      end
    end

    def destroy
      membership = current_organization.organization_memberships.find(params[:id])
      membership.destroy
      if membership.destroyed?
        redirect_to organization_admin_admins_path, notice: "Organization admin access removed."
      else
        redirect_to organization_admin_admins_path, alert: membership.errors.full_messages.to_sentence
      end
    end

    private

    def load_admin_data
      @memberships = current_organization.organization_memberships.includes(:user).order("users.email_address")
      @invitations = current_organization.invitations.outstanding.organization_admin
    end
  end
end
