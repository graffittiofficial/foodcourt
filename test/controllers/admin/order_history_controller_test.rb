require "test_helper"

class Admin::OrderHistoryControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = AdminAccount.create!(email_address: "history-admin@example.test", password: "password")
    @restaurant = create_restaurant(name: "History Bistro")
    @menu_item = MenuItem.create!(restaurant: @restaurant, name: "Noodles", price: "8.50")
    sign_in_as(@admin)
  end

  test "chart filters are applied to the read-only order history" do
    matching = create_order(
      restaurant: @restaurant,
      status: :completed,
      customer_name: "Matching Customer",
      created_at: Time.zone.today.in_time_zone + 12.hours
    )
    create_order(
      restaurant: @restaurant,
      status: :cancelled,
      customer_name: "Other Customer",
      created_at: 1.day.ago
    )

    get admin_order_history_path, params: {
      range: "7",
      created_on: Time.zone.today.iso8601,
      status: "completed",
      restaurant_id: @restaurant.id
    }

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /Order ##{matching.id}/
    assert_select "tbody", text: /Matching Customer/
    assert_select "tbody", text: /Other Customer/, count: 0
    assert_select "a", text: "Clear filters"
  end

  test "search composes with existing order-history filters" do
    matching = create_order(
      restaurant: @restaurant,
      status: :completed,
      customer_name: "Matching Customer",
      created_at: Time.current
    )
    create_order(
      restaurant: @restaurant,
      status: :cancelled,
      customer_name: "Other Customer",
      created_at: Time.current
    )

    get admin_order_history_path, params: { q: "completed", status: "completed", range: "7" }

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /Order ##{matching.id}/
    assert_select "input[name='status'][value='completed']"
    assert_select "input[name='range'][value='7']"
  end

  test "order history paginates newest-first in pages of 25" do
    26.times do |index|
      create_order(
        restaurant: @restaurant,
        status: :pending,
        customer_name: "History Customer #{index}",
        created_at: index.minutes.ago
      )
    end

    get admin_order_history_path

    assert_response :success
    assert_select "tbody tr", count: 25
    assert_select "a", text: "Next"

    get admin_order_history_path, params: { page: 2 }

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "a", text: "Previous"
  end

  test "invalid history filters are rejected" do
    get admin_order_history_path, params: { status: "unknown" }

    assert_response :bad_request
  end

  private

  def create_order(restaurant:, status:, customer_name:, created_at:)
    customer = User.create!(
      email_address: "customer-#{SecureRandom.hex(5)}@example.test",
      password: "password"
    )
    checkout = Checkout.create!(
      user: customer,
      status: :paid,
      customer_name: customer_name,
      customer_phone: "+15555550123",
      address_line1: "100 Main Street",
      city: "Townsville",
      region: "CA",
      postal_code: "90210",
      country_code: "US",
      total_amount_cents: 10_000
    )
    checkout_group = CheckoutGroup.create!(checkout:, restaurant:, distance_km: 3, delivery_fee: "2.50")
    order = Order.create!(restaurant:, checkout_group:, user: customer, customer_name:, status:)
    order.order_items.create!(menu_item: @menu_item, quantity: 1)
    order.update!(created_at:)
    order
  end
end
