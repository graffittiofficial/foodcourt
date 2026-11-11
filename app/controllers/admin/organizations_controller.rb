module Admin
  class OrganizationsController < BaseController
    def index
      load_data
    end

    def create
      Organization.transaction do
        @organization = Organization.create!(name: params.dig(:organization, :name))
        invitation = @organization.invitations.new(
          email_address: params.dig(:organization, :admin_email_address),
          role: :organization_admin,
          invited_by_admin: Current.account
        )
        invitation.save!
        InvitationsMailer.invite(invitation, invitation.token).deliver_later
      end
      redirect_to admin_organizations_path, notice: "Organization created and its first admin invited."
    rescue ActiveRecord::RecordInvalid => error
      @organization = error.record.is_a?(Organization) ? error.record : Organization.new(name: params.dig(:organization, :name))
      @organization.errors.add(:base, error.record.errors.full_messages.to_sentence) unless error.record.is_a?(Organization)
      load_data
      render :index, status: :unprocessable_entity
    end

    def destroy
      organization = Organization.find(params[:id])
      organization.destroy
      if organization.destroyed?
        redirect_to admin_organizations_path, notice: "Organization deleted."
      else
        redirect_to admin_organizations_path, alert: organization.errors.full_messages.to_sentence
      end
    end

    private

    def load_data
      @query = params[:q].to_s.strip
      @organizations = Search::Filter.organizations(
        Organization.includes(:restaurants, :organization_memberships).order(:name),
        @query
      )
      @organization ||= Organization.new
      @invitations = Invitation.outstanding.organization_admin.includes(:organization).order(:created_at)
    end
  end
end
