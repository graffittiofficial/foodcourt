require "test_helper"

class AdminRestaurantsControllerTest < ActionDispatch::IntegrationTest
  test "incomplete Stripe onboarding does not enable online ordering" do
    admin = AdminAccount.create!(email_address: "admin@example.test", password: "password")
    restaurant = Restaurant.create!(
      name: "Corner Table",
      stripe_account_id: "acct_incomplete",
      address_line1: "1 Restaurant Way",
      city: "Townsville",
      region: "CA",
      postal_code: "90210",
      country_code: "US",
      google_place_id: "restaurant-place",
      delivery_base_fee: "1.00",
      delivery_fee_per_km: "0.50",
      max_delivery_distance_km: "25"
    )
    stripe_account = Struct.new(:details_submitted, :payouts_enabled).new(false, false)
    stripe = Object.new
    stripe.define_singleton_method(:retrieve_account) { |_restaurant| stripe_account }
    sign_in_as(admin)

    original_new = StripeGateway.method(:new)
    StripeGateway.define_singleton_method(:new) { stripe }
    begin
      get edit_admin_restaurant_path(restaurant, connect: "return")
    ensure
      StripeGateway.define_singleton_method(:new, original_new)
    end

    assert_response :success
    assert_match "Stripe still requires onboarding details", response.body
    assert_nil restaurant.reload.stripe_account_onboarded_at
  end
end
