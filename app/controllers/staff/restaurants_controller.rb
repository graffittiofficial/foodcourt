module Staff
  class RestaurantsController < BaseController
    skip_before_action :set_current_restaurant

    def index
      @restaurants = available_restaurants.includes(:organization).order(:name)
    end

    def select
      restaurant = available_restaurants.find(params[:id])
      session[:staff_restaurant_id] = restaurant.id
      redirect_to staff_dashboard_path
    end
  end
end
