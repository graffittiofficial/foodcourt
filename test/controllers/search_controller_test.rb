require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = create_organization(name: "Scoped Group")
    @restaurant = create_restaurant(
      name: "Scoped Kitchen",
      organization: @organization,
      city: "Northville",
      address_line1: "100 Main Street",
      region: "CA",
      postal_code: "90210",
      country_code: "US",
      google_place_id: "search-test-place",
      delivery_base_fee: 1,
      delivery_fee_per_km: 1,
      max_delivery_distance_km: 10
    )
    @other_organization = create_organization(name: "Outside Group")
    @other_restaurant = create_restaurant(name: "Outside Kitchen", organization: @other_organization)
    @admin = AdminAccount.create!(email_address: "search-admin@example.test", password: "password")
    @organization_admin = User.create!(email_address: "search-org@example.test", password: "password")
    OrganizationMembership.create!(organization: @organization, user: @organization_admin)
    @customer = User.create!(name: "Search Customer", email_address: "search-customer@example.test", password: "password")
    @other_customer = User.create!(name: "Other Customer", email_address: "other-customer@example.test", password: "password")
    @driver = create_driver(name: "Scoped Driver", email_address: "scoped-driver@example.test")
    @other_driver = create_driver(name: "Outside Driver", email_address: "outside-driver@example.test")
    @menu_item = MenuItem.create!(restaurant: @restaurant, name: "Scoped Noodles", price: "8.50")
  end

  test "public search exposes only restaurants" do
    create_order(restaurant: @restaurant, customer: @customer, delivery_status: :delivered, review_body: "Private customer review")

    get search_path, params: { q: "Scoped" }

    assert_response :success
    assert_select "[data-search-type='restaurants']"
    assert_select "[data-search-type='organizations']", count: 0
    assert_select "[data-search-type='drivers']", count: 0
    assert_select "[data-search-type='orders']", count: 0
    assert_select "[data-search-type='reviews']", count: 0
    assert_no_match "Private customer review", response.body
  end

  test "platform admins can search all requested record types" do
    order = create_order(
      restaurant: @restaurant,
      customer: @customer,
      driver: @driver,
      delivery_status: :delivered,
      review_body: "Wonderful scoped meal"
    )
    sign_in_as(@admin)

    get search_path, params: { q: "Scoped" }

    assert_response :success
    %w[organizations restaurants drivers orders deliveries reviews].each do |type|
      assert_select "[data-search-type='#{type}']"
    end
    assert_select "a[href='#{admin_order_history_path(q: order.id, anchor: "order-#{order.id}")}']"
  end

  test "organization admins see only organization-scoped search results" do
    create_order(
      restaurant: @restaurant,
      customer: @customer,
      driver: @driver,
      delivery_status: :delivered,
      review_body: "Scoped organization review"
    )
    create_order(
      restaurant: @other_restaurant,
      customer: @other_customer,
      driver: @other_driver,
      delivery_status: :delivered,
      review_body: "Outside organization review"
    )
    sign_in_as(@organization_admin, select_restaurant: false)
    patch switch_organizations_path, params: { organization_id: @organization.id }

    get search_path, params: { q: "Scoped" }

    assert_response :success
    assert_select "[data-search-type='organizations']", text: /Scoped Group/
    assert_select "[data-search-type='restaurants']", text: /Scoped Kitchen/
    assert_select "[data-search-type='restaurants']", text: /Outside Kitchen/, count: 0
    assert_select "[data-search-type='drivers']", text: /Scoped Driver/
    assert_select "[data-search-type='drivers']", text: /Outside Driver/, count: 0
    assert_select "[data-search-type='orders']"
    assert_select "[data-search-type='reviews']", text: /Scoped organization review/
    assert_select "[data-search-type='reviews']", text: /Outside organization review/, count: 0
  end

  test "customers see public restaurants, their own orders, and only their own reviews" do
    create_order(
      restaurant: @restaurant,
      customer: @customer,
      delivery_status: :delivered,
      review_body: "My private review"
    )
    create_order(
      restaurant: @restaurant,
      customer: @other_customer,
      delivery_status: :delivered,
      review_body: "Someone else's private review"
    )
    sign_in_as(@customer)

    get search_path, params: { q: "private review" }

    assert_response :success
    assert_select "[data-search-type='restaurants'] a", count: 0
    assert_select "[data-search-type='organizations']", count: 0
    assert_select "[data-search-type='drivers']", count: 0
    assert_select "[data-search-type='orders'] a", count: 0
    assert_select "[data-search-type='reviews']", text: /My private review/
    assert_select "[data-search-type='reviews']", text: /Someone else's private review/, count: 0
  end

  test "drivers can search only their assigned deliveries" do
    my_order = create_order(restaurant: @restaurant, customer: @customer, driver: @driver)
    create_order(restaurant: @other_restaurant, customer: @other_customer, driver: @other_driver)
    sign_in_as(@driver)

    get search_path, params: { q: my_order.id }

    assert_response :success
    assert_select "[data-search-type='deliveries']", text: /Order ##{my_order.id}/
    assert_select "[data-search-type='orders']", count: 0
    assert_select "[data-search-type='organizations']", count: 0
    assert_select "[data-search-type='restaurants']", count: 0
  end

  test "type filters paginate all matching results" do
    11.times { |index| create_restaurant(name: "Page Search #{index}") }

    get search_path, params: { q: "page search", type: "restaurants" }

    assert_response :success
    assert_select "[data-search-type='restaurants'] li", count: 10
    assert_select "a[href='#{search_path(q: "page search", type: "restaurants", page: 2)}']", text: "Next"

    get search_path, params: { q: "page search", type: "restaurants", page: 2 }

    assert_response :success
    assert_select "[data-search-type='restaurants'] li", count: 1
  end

  test "invalid search type and page are rejected" do
    get search_path, params: { q: "anything", type: "customers" }
    assert_response :bad_request

    get search_path, params: { q: "anything", page: "0" }
    assert_response :bad_request
  end

  private

  def create_driver(name:, email_address:)
    User.create!(name:, email_address:, password: "password", role: :driver)
  end

  def create_order(restaurant:, customer:, driver: nil, delivery_status: :assigned, review_body: nil)
    menu_item = if restaurant == @restaurant
      @menu_item
    else
      MenuItem.create!(restaurant:, name: "Outside Noodles", price: "8.50")
    end
    order = Order.create!(
      restaurant:,
      user: customer,
      customer_name: customer.name,
      driver:,
      status: :completed,
      delivery_status:
    )
    order.order_items.create!(menu_item:, quantity: 1, unit_price: menu_item.price)
    if review_body
      order.reviews.create!(
        user: customer,
        reviewable: restaurant,
        rating: 5,
        body: review_body
      )
    end
    order
  end
end
