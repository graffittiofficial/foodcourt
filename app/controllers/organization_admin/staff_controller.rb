module OrganizationAdmin
  class StaffController < BaseController
    def index
      load_staff_data
    end

    def create
      restaurant_ids = Array(params.dig(:staff, :restaurant_ids)).reject(&:blank?).uniq
      restaurants = current_organization.restaurants.where(id: restaurant_ids)
      if restaurants.size != restaurant_ids.size
        @invitation = current_organization.invitations.new
        @invitation.errors.add(:restaurants, "must all belong to this Organization")
      else
        @invitation = invite_user(
          role: :staff,
          email_address: params.dig(:staff, :email_address),
          restaurants: restaurants
        )
      end
      if @invitation.persisted?
        redirect_to organization_admin_staff_index_path, notice: "Staff invitation sent."
      else
        load_staff_data
        render :index, status: :unprocessable_entity
      end
    end

    def destroy
      membership = RestaurantMembership.joins(:restaurant)
        .where(restaurants: { organization_id: current_organization.id })
        .find(params[:id])
      membership.destroy!
      redirect_to organization_admin_staff_index_path, notice: "Restaurant staff access removed."
    end

    private

    def load_staff_data
      @restaurants = current_organization.restaurants.order(:name)
      @memberships = RestaurantMembership.joins(:restaurant)
        .includes(:user, :restaurant)
        .where(restaurants: { organization_id: current_organization.id })
        .order("users.email_address", "restaurants.name")
      @invitations = current_organization.invitations.outstanding.staff
        .includes(:invitation_restaurants, :restaurants)
    end
  end
end
