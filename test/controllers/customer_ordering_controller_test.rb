require "test_helper"

class CustomerOrderingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @restaurant = Restaurant.create!(name: "Corner Table")
    @menu_item = MenuItem.create!(restaurant: @restaurant, name: "Soup", price: "8.50")
  end

  class ApplicationControllerOriginTest < ActiveSupport::TestCase
    test "localhost proxy origin remains rejected outside development" do
      request = ActionDispatch::TestRequest.create(
        "HTTP_HOST" => "codespace.example.test",
        "HTTPS" => "on",
        "HTTP_ORIGIN" => "https://localhost:3000"
      )
      controller = ApplicationController.new
      controller.set_request!(request)

      assert_not controller.send(:valid_request_origin?)
    end
  end

  test "restaurant menus and guest baskets are public" do
    get restaurant_path(@restaurant)
    assert_response :success
    assert_select "h1", text: "Corner Table"

    post cart_items_path, params: { menu_item_id: @menu_item.id, quantity: "2" }
    assert_redirected_to restaurant_path(@restaurant)
    follow_redirect!
    assert_select "h2", text: "Soup"
    assert_select "h1", text: "Corner Table"
  end

  test "restaurant search filters names and public pages show verified ratings" do
    other_restaurant = Restaurant.create!(name: "Blue Garden")
    customer = User.create!(name: "Review Customer", email_address: "reviewer@example.test", password: "password")
    order = Order.create!(
      restaurant: @restaurant,
      user: customer,
      customer_name: customer.name,
      delivery_status: :delivered
    )
    order.order_items.create!(menu_item: @menu_item, quantity: 1, unit_price: @menu_item.price)
    sign_in_as(customer)
    post order_reviews_path(order), params: {
      review: { reviewable_type: "Restaurant", rating: "5", body: "Loved it." }
    }
    post order_reviews_path(order), params: {
      review: { reviewable_type: "MenuItem", menu_item_id: @menu_item.id, rating: "4", body: "Great soup." }
    }

    get order_path(order)
    assert_response :success
    assert_select "h1", text: /Corner Table/
    assert_select "input[type='radio'][name='review[rating]']", count: 10

    get restaurants_path(q: "Corner")
    assert_response :success
    assert_select "h2", text: "Corner Table"
    assert_select "h2", text: "Blue Garden", count: 0
    assert_select "[aria-label='Rated 5.0 out of 5 from 1 reviews']"

    get restaurant_path(@restaurant)
    assert_response :success
    assert_select "[aria-label='Rated 4.0 out of 5 from 1 reviews']"
    assert_select "li", text: /Great soup/
    assert_select "li", text: /Loved it/
  end

  test "checkout confirmation shows a refresh action while payment is pending" do
    customer = User.create!(name: "Checkout Customer", email_address: "checkout@example.test", password: "password")
    checkout = Checkout.create!(
      user: customer,
      stripe_checkout_session_id: "cs_pending_confirmation",
      customer_name: customer.name,
      customer_phone: "+15555550123",
      address_line1: "100 Main Street",
      city: "Townsville",
      region: "CA",
      postal_code: "90210",
      country_code: "US",
      total_amount_cents: 850
    )
    sign_in_as(customer)

    get checkout_success_path(session_id: checkout.stripe_checkout_session_id)

    assert_response :success
    assert_select "h1", text: "Confirming your payment"
    assert_select "a", text: "Refresh order status"
  end

  test "ratings require a delivered order and can be edited and deleted by their customer" do
    customer = User.create!(name: "Review Customer", email_address: "reviewer@example.test", password: "password")
    order = Order.create!(restaurant: @restaurant, user: customer, customer_name: customer.name)
    order.order_items.create!(menu_item: @menu_item, quantity: 1, unit_price: @menu_item.price)
    sign_in_as(customer)

    post order_reviews_path(order), params: {
      review: { reviewable_type: "Restaurant", rating: "5", body: "Loved it." }
    }
    assert_equal 0, Review.count

    order.update!(delivery_status: :assigned)
    order.update!(delivery_status: :picked_up)
    order.update!(delivery_status: :delivered)
    post order_reviews_path(order), params: {
      review: { reviewable_type: "Restaurant", rating: "5", body: "Loved it." }
    }
    review = Review.sole
    patch review_path(review), params: { review: { rating: "3", body: "Updated feedback." } }
    assert_equal 3, review.reload.rating

    other_customer = User.create!(name: "Other Customer", email_address: "other@example.test", password: "password")
    sign_out
    sign_in_as(other_customer)
    patch review_path(review), params: { review: { rating: "1" } }
    assert_response :not_found

    sign_out
    sign_in_as(customer)
    delete review_path(review)
    assert_not Review.exists?(review.id)
  end

  test "guest basket survives account creation and requires sign-in only at checkout" do
    post cart_items_path, params: { menu_item_id: @menu_item.id, quantity: "2" }
    get new_checkout_path
    assert_redirected_to new_session_path

    post registration_path, params: {
      user: {
        name: "New Customer",
        email_address: "new-customer@example.test",
        password: "password",
        password_confirmation: "password"
      }
    }
    assert_redirected_to new_checkout_path

    get new_checkout_path
    assert_response :success
    customer = User.find_by!(email_address: "new-customer@example.test")
    assert_equal 2, customer.cart.cart_items.find_by!(menu_item: @menu_item).quantity
    assert_select "input[name='checkout[customer_phone]']"
  end

  test "a customer cannot view another customer's orders" do
    first_customer = User.create!(name: "First Customer", email_address: "first@example.test", password: "password")
    second_customer = User.create!(name: "Second Customer", email_address: "second@example.test", password: "password")
    order = Order.create!(restaurant: @restaurant, user: first_customer, customer_name: first_customer.name)
    sign_in_as(second_customer)

    get order_path(order)

    assert_response :not_found
  end
end
