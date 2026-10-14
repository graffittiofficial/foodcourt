class CheckoutsController < ApplicationController
  before_action :require_customer

  def new
    @basket = customer_basket
    @entries = @basket.entries
    @total = @basket.active_entries.sum { |entry| entry.menu_item.price * entry.quantity }
    @customer_name = Current.account.name
  end

  def create
    @basket = customer_basket
    @entries = @basket.entries
    @total = @basket.active_entries.sum { |entry| entry.menu_item.price * entry.quantity }

    result = CheckoutBuilder.new(
      user: Current.account,
      entries: @entries,
      address: checkout_params,
    ).call(
      success_url: checkout_success_url(session_id: "{CHECKOUT_SESSION_ID}"),
      cancel_url: cart_url
    )
    redirect_to result.fetch(:stripe_session).url, allow_other_host: true
  rescue CheckoutBuilder::Error, ActiveRecord::RecordInvalid, ActionController::ParameterMissing => error
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  rescue GoogleRoutes::Error, GooglePlaces::Error, StripeGateway::ConfigurationError, Stripe::StripeError => error
    Rails.logger.error("Checkout could not be started: #{error.class}: #{error.message}")
    flash.now[:alert] = "Checkout is temporarily unavailable. Please try again later."
    render :new, status: :service_unavailable
  end

  def success
    @checkout = Current.account.checkouts.includes(checkout_groups: :order)
      .find_by!(stripe_checkout_session_id: params.require(:session_id))
  end

  private

  def require_customer
    return if Current.account.is_a?(User) && Current.account.customer?

    redirect_to root_path, alert: "Customer access is required."
  end

  def customer_basket
    ShoppingBasket.new(session: session, user: Current.account)
  end

  def checkout_params
    params.require(:checkout).permit(
      :customer_name,
      :customer_phone,
      :address_line1,
      :address_line2,
      :city,
      :region,
      :postal_code,
      :country_code,
      :google_place_id
    ).to_h.symbolize_keys
  end
end
