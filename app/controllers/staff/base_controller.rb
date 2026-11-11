module Staff
  class BaseController < ApplicationController
    before_action :require_staff
    before_action :set_current_organization
    before_action :set_current_restaurant

    private

    def require_staff
      return if Current.user.is_a?(User) && (Current.user.staff? || Current.user.organization_admin?)

      head :forbidden
    end

    def current_restaurant
      Current.restaurant
    end

    def set_current_restaurant
      restaurants = available_restaurants
      Current.restaurant = restaurants.find_by(id: session[:staff_restaurant_id])
      return if Current.restaurant

      session.delete(:staff_restaurant_id)
      redirect_to staff_restaurants_path
    end

    def set_current_organization
      return unless Current.user.organization_admin?

      Current.organization = Current.user.administered_organizations.find_by(id: session[:organization_id])
      return if Current.organization

      session.delete(:organization_id)
      session.delete(:staff_restaurant_id)
      redirect_to organizations_path
    end

    def available_restaurants
      return Current.user.restaurants unless Current.organization

      Restaurant.where(organization_id: Current.organization.id)
    end
  end
end
