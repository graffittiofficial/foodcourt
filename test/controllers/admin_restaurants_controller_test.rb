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

  test "admins can upload restaurant and menu item photos" do
    admin = AdminAccount.create!(email_address: "photos-admin@example.test", password: "password")
    restaurant = Restaurant.create!(name: "Photo Test Restaurant")
    menu_item = MenuItem.create!(restaurant: restaurant, name: "Photo Test Soup", price: "4.00")
    sign_in_as(admin)

    patch admin_restaurant_path(restaurant), params: {
      restaurant: { photo: fixture_file_upload(Rails.root.join("public/icon.png"), "image/png") }
    }
    assert_redirected_to edit_admin_restaurant_path(restaurant)
    assert restaurant.reload.photo.attached?
    get edit_admin_restaurant_path(restaurant)
    assert_response :success
    assert_select "img[alt='Photo Test Restaurant']"

    patch admin_restaurant_menu_item_path(restaurant, menu_item), params: {
      menu_item: { photo: fixture_file_upload(Rails.root.join("public/icon.png"), "image/png") }
    }
    assert_redirected_to edit_admin_restaurant_path(restaurant)
    assert menu_item.reload.photo.attached?
    get edit_admin_restaurant_path(restaurant)
    assert_response :success
    assert_select "img[alt='Photo Test Soup']"
  end

  test "admins can remove publicly published customer reviews" do
    admin = AdminAccount.create!(email_address: "review-admin@example.test", password: "password")
    customer = User.create!(name: "Review Customer", email_address: "review-owner@example.test", password: "password")
    restaurant = Restaurant.create!(name: "Reviewed Restaurant")
    menu_item = MenuItem.create!(restaurant: restaurant, name: "Reviewed Dish", price: "8.00")
    order = Order.create!(
      restaurant: restaurant,
      user: customer,
      customer_name: customer.name,
      delivery_status: :delivered
    )
    order.order_items.create!(menu_item: menu_item, quantity: 1, unit_price: menu_item.price)
    review = Review.create!(user: customer, order: order, reviewable: restaurant, rating: 1, body: "Inappropriate")
    sign_in_as(admin)

    get admin_reviews_path
    assert_response :success
    assert_select "li", text: /Inappropriate/

    delete admin_review_path(review)
    assert_redirected_to admin_reviews_path
    assert_not Review.exists?(review.id)
  end
end
