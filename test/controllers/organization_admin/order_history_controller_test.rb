require "test_helper"

class OrganizationAdmin::OrderHistoryControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = create_organization(name: "History Organization")
    @restaurant = create_restaurant(name: "History Restaurant", organization: @organization)
    @outside_restaurant = create_restaurant(name: "Outside Restaurant")
    @admin = User.create!(email_address: "organization-history@example.test", password: "password")
    OrganizationMembership.create!(organization: @organization, user: @admin)
    sign_in_as(@admin, select_restaurant: false)
    patch switch_organizations_path, params: { organization_id: @organization.id }
  end

  test "chart filters and text search apply within the current Organization" do
    matching = create_order(@restaurant, status: :completed, customer_name: "Matching Customer")
    create_order(@restaurant, status: :pending, customer_name: "Other Customer")
    outside = create_order(@outside_restaurant, status: :completed, customer_name: "Outside Customer")

    get organization_admin_order_history_path, params: {
      range: "30",
      created_on: Time.zone.today.iso8601,
      status: "completed",
      restaurant_id: @restaurant.id,
      q: matching.id.to_s
    }

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /Order ##{matching.id}/
    assert_select "tbody", text: /Order ##{outside.id}/, count: 0
    assert_select "a", text: "Clear chart filters"
    assert_select "a[href='#{organization_admin_order_history_path(q: matching.id)}']", text: "Clear chart filters"
  end

  test "history paginates 25 rows and preserves chart filters and search" do
    26.times do |index|
      create_order(@restaurant, status: :pending, customer_name: "Pagination Customer #{index}")
    end

    get organization_admin_order_history_path, params: { range: "30", status: "pending", q: "pending" }

    assert_response :success
    assert_select "tbody tr", count: 25
    assert_select "a[href*='range=30'][href*='status=pending'][href*='q=pending'][href*='page=2']", text: "Next"

    get organization_admin_order_history_path, params: { range: "30", status: "pending", q: "pending", page: 2 }

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "a", text: "Previous"
  end

  test "invalid and cross-Organization filters are rejected" do
    get organization_admin_order_history_path, params: { status: "unknown" }
    assert_response :bad_request

    get organization_admin_order_history_path, params: { restaurant_id: @outside_restaurant.id }
    assert_response :bad_request
  end

  private

  def create_order(restaurant, status:, customer_name:)
    customer = User.create!(
      email_address: "history-customer-#{SecureRandom.hex(5)}@example.test",
      password: "password"
    )
    Order.create!(restaurant:, user: customer, customer_name:, status:)
  end
end
