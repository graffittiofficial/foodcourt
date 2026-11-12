require "test_helper"

class OrganizationAdmin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = create_organization(name: "Dashboard Organization")
    @restaurant = create_restaurant(name: "Main Restaurant", organization: @organization)
    @second_restaurant = create_restaurant(name: "Second Restaurant", organization: @organization)
    @outside_restaurant = create_restaurant(name: "Outside Restaurant")
    @admin = User.create!(email_address: "organization-dashboard@example.test", password: "password")
    OrganizationMembership.create!(organization: @organization, user: @admin)
    sign_in_as(@admin, select_restaurant: false)
    patch switch_organizations_path, params: { organization_id: @organization.id }
  end

  test "dashboard charts and operations are scoped to the current Organization" do
    customer = User.create!(email_address: "chart-customer@example.test", password: "password")
    completed = create_order(
      restaurant: @restaurant,
      customer: customer,
      status: :completed,
      item_price: "8.50",
      quantity: 2,
      delivery_fee: "2.50"
    )
    create_order(restaurant: @second_restaurant, status: :pending)
    create_order(restaurant: @outside_restaurant, status: :completed)
    empty_completed_order = Order.create!(
      restaurant: @second_restaurant,
      customer_name: "No Item Customer",
      status: :completed
    )
    empty_completed_order.update!(created_at: 2.days.ago)

    get organization_admin_root_path, params: { range: "7" }

    assert_response :success
    assert_select "aside#admin-sidebar"
    assert_select "a", text: "Organization admins"
    assert_select "a", text: "Reports"
    assert_select "a", text: "Order history"
    assert_select "nav[aria-label='Chart date range'] a[aria-current='date']", text: "7 days"
    assert_select "svg[aria-label='Organization orders per day']"
    assert_select "svg[aria-label='Organization completed sales per day']"
    assert_select "svg[aria-label='Organization orders by kitchen status']"
    assert_select "svg[aria-label='Organization Restaurants by completed orders']"
    assert_select "a[href='#{organization_admin_order_history_path(range: "7", created_on: Time.zone.today.iso8601)}']"
    assert_select "a[href='#{organization_admin_order_history_path(range: "7", created_on: Time.zone.today.iso8601, status: "completed")}']"
    assert_select "a[href='#{organization_admin_order_history_path(range: "7", status: "pending")}']"
    assert_select "a[href='#{organization_admin_order_history_path(range: "7", restaurant_id: @restaurant.id, status: "completed")}']"
    assert_includes response.body, "$19.50"
    assert_includes response.body, completed.customer_name
    assert_includes response.body, @restaurant.name
    assert_includes response.body, @second_restaurant.name
    assert_not_includes response.body, @outside_restaurant.name
  end

  test "Organization admins with Restaurant assignments keep staff-workspace links" do
    RestaurantMembership.create!(restaurant: @restaurant, user: @admin)
    patch select_staff_restaurant_path(@restaurant)

    get organization_admin_root_path

    assert_response :success
    assert_select "a", text: "Staff dashboard"
    assert_select "a", text: "Staff orders"
    assert_select "a", text: "Staff menu"
  end

  test "dashboard rejects unsupported chart ranges" do
    get organization_admin_root_path, params: { range: "365" }

    assert_response :bad_request
  end

  test "Organization selection page uses the Organization admin shell without an active Organization" do
    session.delete(:organization_id)

    get organizations_path

    assert_response :success
    assert_select "aside#admin-sidebar"
    assert_select "h1", text: "Choose an Organization"
    assert_select "header", text: /Choose an Organization/
  end

  private

  def create_order(restaurant:, status:, customer: nil, item_price: "8.50", quantity: 1, delivery_fee: "0")
    customer ||= User.create!(email_address: "customer-#{SecureRandom.hex(5)}@example.test", password: "password")
    checkout_group = nil
    if delivery_fee.to_d.positive?
      checkout = Checkout.create!(
        user: customer,
        status: :paid,
        customer_name: "Chart Customer",
        customer_phone: "+15555550123",
        address_line1: "100 Main Street",
        city: "Townsville",
        region: "CA",
        postal_code: "90210",
        country_code: "US",
        total_amount_cents: 10_000
      )
      checkout_group = CheckoutGroup.create!(checkout:, restaurant:, distance_km: 3, delivery_fee:)
    end
    order = Order.create!(
      restaurant:,
      checkout_group:,
      user: customer,
      customer_name: customer.name.presence || "Chart Customer",
      status:
    )
    menu_item = MenuItem.create!(restaurant:, name: "Item #{SecureRandom.hex(3)}", price: item_price)
    order.order_items.create!(menu_item:, quantity:, unit_price: item_price)
    order
  end
end
