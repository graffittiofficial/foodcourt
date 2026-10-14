module Admin
  class RestaurantsController < BaseController
    before_action :set_restaurant, only: %i[edit update connect]

    def index
      @restaurants = Restaurant.order(:name)
    end

    def new
      @restaurant = Restaurant.new
    end

    def create
      @restaurant = Restaurant.new(restaurant_params)
      if @restaurant.save
        redirect_to edit_admin_restaurant_path(@restaurant), notice: "Restaurant created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      sync_stripe_onboarding if params[:connect] == "return" && @restaurant.stripe_account_id.present?
    end

    def update
      if @restaurant.update(restaurant_params)
        redirect_to edit_admin_restaurant_path(@restaurant), notice: "Restaurant updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def connect
      unless @restaurant.delivery_configured?
        return redirect_to edit_admin_restaurant_path(@restaurant), alert: "Complete the delivery location and pricing settings before connecting Stripe."
      end

      unless @restaurant.stripe_account_id.present?
        account = stripe.create_express_account(@restaurant)
        @restaurant.update!(stripe_account_id: account.id)
      end
      link = stripe.create_account_link(
        restaurant: @restaurant,
        refresh_url: connect_admin_restaurant_url(@restaurant),
        return_url: edit_admin_restaurant_url(@restaurant, connect: "return")
      )
      redirect_to link.url, allow_other_host: true
    rescue StripeGateway::ConfigurationError, Stripe::StripeError, ActiveRecord::RecordInvalid => error
      Rails.logger.error("Stripe onboarding failed for restaurant #{@restaurant.id}: #{error.class}: #{error.message}")
      redirect_to edit_admin_restaurant_path(@restaurant), alert: "Stripe onboarding could not be started. Please try again later."
    end

    private

    def set_restaurant
      @restaurant = Restaurant.find(params[:id])
    end

    def restaurant_params
      params.require(:restaurant).permit(
        :name,
        :description,
        :address_line1,
        :city,
        :region,
        :postal_code,
        :country_code,
        :google_place_id,
        :delivery_base_fee,
        :delivery_fee_per_km,
        :max_delivery_distance_km
      )
    end

    def stripe
      @stripe ||= StripeGateway.new
    end

    def sync_stripe_onboarding
      account = stripe.retrieve_account(@restaurant)
      if account.details_submitted && account.payouts_enabled
        @restaurant.update!(stripe_account_onboarded_at: Time.current) unless @restaurant.stripe_connected?
      else
        flash.now[:alert] = "Stripe still requires onboarding details before this restaurant can accept online orders."
      end
    rescue StripeGateway::ConfigurationError, Stripe::StripeError => error
      Rails.logger.error("Stripe onboarding status failed for restaurant #{@restaurant.id}: #{error.class}: #{error.message}")
      flash.now[:alert] = "Stripe account status could not be checked. Please try again."
    end
  end
end
