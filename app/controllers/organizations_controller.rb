class OrganizationsController < ApplicationController
  layout "organization_admin"

  def index
    return redirect_to admin_root_path if Current.account&.admin?
    return head :forbidden unless Current.user.is_a?(User)

    @organizations = Current.user.administered_organizations.order(:name)
    return redirect_to staff_restaurants_path if @organizations.empty? && Current.user.staff?
    return redirect_to root_path if @organizations.empty?
  end

  def switch
    return head :forbidden unless Current.user.is_a?(User)

    organization = Current.user.administered_organizations.find(params[:organization_id])
    session[:organization_id] = organization.id
    session.delete(:staff_restaurant_id)
    redirect_to organization_admin_root_path
  end
end
