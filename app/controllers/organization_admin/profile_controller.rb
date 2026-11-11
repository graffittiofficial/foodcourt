module OrganizationAdmin
  class ProfileController < BaseController
    def edit
      @organization = current_organization
    end

    def update
      @organization = current_organization
      if @organization.update(organization_params)
        redirect_to organization_admin_root_path, notice: "Organization profile updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def organization_params
      params.require(:organization).permit(:name, :time_zone)
    end
  end
end
