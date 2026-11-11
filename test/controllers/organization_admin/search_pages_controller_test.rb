require "test_helper"

class OrganizationAdmin::SearchPagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = create_organization(name: "Search Organization")
    @restaurant = create_restaurant(name: "Search Restaurant", organization: @organization)
    @outside_restaurant = create_restaurant(name: "Outside Restaurant")
    @admin = User.create!(email_address: "scoped-search-admin@example.test", password: "password")
    OrganizationMembership.create!(organization: @organization, user: @admin)
    @customer = User.create!(name: "Scoped Customer", email_address: "scoped-customer@example.test", password: "password")
    @menu_item = MenuItem.create!(restaurant: @restaurant, name: "Scoped Item", price: "8.50")
    @order = create_order(@restaurant, @menu_item, @customer, "Scoped review")
    @outside_order = create_order(@outside_restaurant, MenuItem.create!(restaurant: @outside_restaurant, name: "Outside Item", price: "8.50"), @customer, "Outside review")
    sign_in_as(@admin, select_restaurant: false)
    patch switch_organizations_path, params: { organization_id: @organization.id }
  end

  test "organization-scoped order history and reviews are searchable without showing outside records" do
    get organization_admin_order_history_path, params: { q: @order.id }

    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "tbody", text: /Order ##{@order.id}/
    assert_select "tbody", text: /Outside Restaurant/, count: 0

    get organization_admin_reviews_path, params: { q: "Scoped review" }

    assert_response :success
    assert_select "li", text: /Scoped review/
    assert_select "li", text: /Outside review/, count: 0
  end

  private

  def create_order(restaurant, menu_item, customer, review_body)
    order = Order.create!(
      restaurant:,
      user: customer,
      customer_name: customer.name,
      status: :completed,
      delivery_status: :delivered
    )
    order.order_items.create!(menu_item:, quantity: 1, unit_price: menu_item.price)
    order.reviews.create!(user: customer, reviewable: restaurant, rating: 5, body: review_body)
    order
  end
end
