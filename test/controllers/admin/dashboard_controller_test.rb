require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = AdminAccount.create!(email_address: "dashboard-admin@example.com", password: "password")
    @restaurant = Restaurant.create!(name: "Dashboard Bistro")
    @menu_item = MenuItem.create!(restaurant: @restaurant, name: "Noodles", price: "8.50")
    sign_in_as(@admin)
  end

  test "unauthenticated requests redirect to sign in" do
    sign_out

    get admin_root_path

    assert_redirected_to new_session_path
  end

  test "dashboard summarizes completed sales, today's orders, setup, and delivery queues" do
    customer = User.create!(name: "Dashboard Customer", email_address: "dashboard-customer@example.com", password: "password")
    driver = User.create!(name: "Driver", email_address: "driver@example.com", password: "password", role: :driver)
    completed_today = create_order(customer:, status: :completed, quantity: 2, delivery_fee: "2.50")
    completed_yesterday = create_order(customer:, status: :completed, quantity: 1, delivery_fee: "1.25", created_at: 1.day.ago)
    create_order(customer:, status: :pending, quantity: 1, delivery_fee: "1.00")
    pending_restaurant_order = Order.create!(restaurant: @restaurant, customer_name: "Walk-in customer")
    create_order(customer:, status: :cancelled, quantity: 1, delivery_fee: "1.00")
    completed_today.update!(delivery_status: :assigned, driver:)
    completed_yesterday.update!(delivery_status: :assigned, driver:)
    ready_restaurant = create_ready_restaurant

    get admin_root_path

    assert_response :success
    assert_select "section[aria-label='Sales overview'] article", count: 4
    assert_select "section[aria-label='Sales overview']", text: /All-time sales.*2/m
    assert_select "section[aria-label='Sales overview']", text: /All-time revenue.*\$29\.25/m
    assert_select "section[aria-label='Sales overview']", text: /Today's orders.*3/m
    assert_select "h2", text: "Pending orders"
    assert_match(/Order ##{pending_restaurant_order.id}/, response.body)
    assert_select "section[aria-label='Sales overview']", text: /Today's revenue.*\$19\.50/m
    assert_select "h2", text: "Unassigned deliveries"
    assert_match(/Order ##{Order.find_by!(status: :pending).id}/, response.body)
    assert_select "a[href='#{edit_admin_restaurant_path(ready_restaurant)}']", count: 0
    assert_select "a", text: "Complete setup"
    assert_match(/Dashboard Bistro/, response.body)
    assert_select "h2", text: "Recent orders"
    assert_select "a[href='#{admin_orders_path}']", text: "Manage deliveries"
  end

  test "dashboard shows helpful empty states when there is no operational work" do
    get admin_root_path

    assert_response :success
    assert_select "p", text: "No orders are waiting to be started."
    assert_select "p", text: "No deliveries are waiting for assignment."
    assert_select "p", text: "No orders yet."
    assert_select "p", text: "$0.00", count: 2
  end

  private

  def create_order(customer:, status:, quantity:, delivery_fee:, created_at: Time.current)
    checkout = Checkout.create!(
      user: customer,
      status: :paid,
      customer_name: customer.name,
      customer_phone: "+15555550123",
      address_line1: "100 Main Street",
      city: "Townsville",
      region: "CA",
      postal_code: "90210",
      country_code: "US",
      total_amount_cents: 10_000
    )
    checkout_group = CheckoutGroup.create!(
      checkout: checkout,
      restaurant: @restaurant,
      distance_km: 3,
      delivery_fee:
    )
    order = Order.create!(
      restaurant: @restaurant,
      checkout_group:,
      user: customer,
      customer_name: customer.name,
      status:
    )
    order.order_items.create!(menu_item: @menu_item, quantity:)
    order.update!(created_at:)
    order
  end

  def create_ready_restaurant
    Restaurant.create!(
      name: "Ready Bistro",
      address_line1: "1 Restaurant Way",
      city: "Townsville",
      region: "CA",
      postal_code: "90210",
      country_code: "US",
      google_place_id: "ready-bistro",
      delivery_base_fee: "1.00",
      delivery_fee_per_km: "0.50",
      max_delivery_distance_km: "25",
      stripe_account_id: "acct_ready_bistro",
      stripe_account_onboarded_at: Time.current
    )
  end
end
