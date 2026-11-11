module OrganizationAdmin
  class RestaurantsController < BaseController
    before_action :set_restaurant, only: %i[edit update]

    def index
      @query = params[:q].to_s.strip
      @restaurants = Search::Filter.restaurants(current_organization.restaurants.order(:name), @query)
    end

    def new
      @restaurant = current_organization.restaurants.new
    end

    def create
      @restaurant = current_organization.restaurants.new(restaurant_params)
      if @restaurant.save
        redirect_to edit_organization_admin_restaurant_path(@restaurant), notice: "Restaurant created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @restaurant.update(restaurant_params)
        redirect_to edit_organization_admin_restaurant_path(@restaurant), notice: "Restaurant updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_restaurant
      @restaurant = current_organization.restaurants.find(params[:id])
    end

    def restaurant_params
      params.require(:restaurant).permit(
        :name, :description, :photo, :address_line1, :city, :region, :postal_code, :country_code,
        :google_place_id, :delivery_base_fee, :delivery_fee_per_km, :max_delivery_distance_km
      )
    end
  end
end
