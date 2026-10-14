require "test_helper"

class Staff::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @restaurant = Restaurant.create!(name: "Bistro")
    @staff = User.create!(
      email_address: "staff@example.com",
      password: "password",
      role: :staff,
      restaurant: @restaurant
    )
    @menu_item = MenuItem.create!(restaurant: @restaurant, name: "Soup", price: 8)
  end

  test "unauthenticated requests redirect to sign in" do
    get staff_dashboard_path

    assert_redirected_to new_session_path
  end

  test "non-staff users are forbidden from the staff dashboard" do
    sign_in_as(User.create!(email_address: "customer@example.com", password: "password"))

    get staff_dashboard_path

    assert_response :forbidden
  end

  test "dashboard shows restaurant-scoped counts and completed sales for today" do
    sign_in_as(@staff)
    completed_order = create_order(status: :completed, quantity: 2)
    create_order(status: :pending)
    create_order(status: :cancelled)
    create_order(status: :completed, created_at: 1.day.ago)

    other_restaurant = Restaurant.create!(name: "Other Bistro")
    MenuItem.create!(restaurant: other_restaurant, name: "Cake", price: 50)
    Order.create!(restaurant: other_restaurant, customer_name: "Other", status: :completed)

    get staff_dashboard_path

    assert_response :success
    assert_select "section[aria-label=\"Today's summary\"] p", text: "2", count: 1
    assert_select "section[aria-label=\"Today's summary\"] p", text: "1", count: 1
    assert_select "section[aria-label=\"Today's summary\"] p", text: "$16.00", count: 1
    assert_select "a", text: "Order ##{completed_order.id}"
    assert_no_match(/Other Bistro|Cake/, response.body)
  end

  test "dashboard shows a useful empty state before the first order" do
    sign_in_as(@staff)

    get staff_dashboard_path

    assert_response :success
    assert_select "p", text: "0", count: 2
    assert_select "p", text: "$0.00"
    assert_match(/No orders yet/, response.body)
  end

  test "orders are scoped to the signed-in staff restaurant" do
    sign_in_as(@staff)
    other_restaurant = Restaurant.create!(name: "Other Bistro")
    order = Order.create!(restaurant: other_restaurant, customer_name: "Private")

    get staff_order_path(order)

    assert_response :not_found
  end

  test "staff can create menu items and change availability" do
    sign_in_as(@staff)

    post staff_menu_items_path, params: {
      menu_item: { name: "Salad", description: "Fresh", price: "9.50", available: "1" }
    }

    item = @restaurant.menu_items.find_by!(name: "Salad")
    assert_redirected_to staff_menu_items_path
    assert item.available?

    other_restaurant = Restaurant.create!(name: "Other Bistro")
    patch staff_menu_item_path(item), params: {
      menu_item: {
        name: "Green Salad",
        description: "Updated description",
        price: "11.25",
        available: "0",
        restaurant_id: other_restaurant.id
      }
    }

    assert_redirected_to staff_menu_items_path
    assert_not item.reload.available?
    assert_equal "Green Salad", item.name
    assert_equal BigDecimal("11.25"), item.price
    assert_equal @restaurant, item.restaurant
  end

  test "invalid menu item prices render validation errors without saving" do
    sign_in_as(@staff)

    assert_no_difference("MenuItem.count") do
      post staff_menu_items_path, params: { menu_item: { name: "Bad price", price: "0" } }
    end

    assert_response :unprocessable_entity
    assert_select '[role="alert"]'
  end

  test "staff can archive their menu items but cannot access another restaurant item" do
    sign_in_as(@staff)
    other_restaurant = Restaurant.create!(name: "Other Bistro")
    other_item = MenuItem.create!(restaurant: other_restaurant, name: "Cake", price: 5)

    patch archive_staff_menu_item_path(@menu_item)
    assert_not @menu_item.reload.available?
    assert_not_nil @menu_item.archived_at
    assert_not_includes @restaurant.menu_items.active, @menu_item

    patch archive_staff_menu_item_path(other_item)

    assert_response :not_found
  end

  test "staff can create an order using only available items at the current price" do
    sign_in_as(@staff)
    @menu_item.update!(price: 10)

    assert_difference("Order.count", 1) do
      post staff_orders_path, params: {
        order: {
          customer_name: "Taylor",
          restaurant_id: Restaurant.create!(name: "Other Bistro").id,
          created_by_id: User.create!(email_address: "other@example.com", password: "password").id,
          status: "completed",
          order_items_attributes: {
            "0" => { menu_item_id: @menu_item.id, quantity: "2" }
          }
        }
      }
    end

    order = Order.order(:id).last
    assert_redirected_to staff_order_path(order)
    assert_equal @staff, order.created_by
    assert_equal "Taylor", order.customer_name
    assert_equal @restaurant, order.restaurant
    assert_equal "pending", order.status
    assert_equal BigDecimal("20.00"), order.total
  end

  test "order creation rejects empty, unavailable, and cross-restaurant item selections" do
    sign_in_as(@staff)
    other_restaurant = Restaurant.create!(name: "Other Bistro")
    other_item = MenuItem.create!(restaurant: other_restaurant, name: "Cake", price: 5)
    @menu_item.update!(available: false)

    assert_no_difference("Order.count") do
      post staff_orders_path, params: { order: { customer_name: "Taylor", order_items_attributes: { "0" => { menu_item_id: @menu_item.id, quantity: "1" } } } }
    end
    assert_response :unprocessable_entity
    assert_match(/no longer available/, response.body)

    @menu_item.update!(available: true)
    assert_no_difference("Order.count") do
      post staff_orders_path, params: { order: { customer_name: "Taylor", order_items_attributes: { "0" => { menu_item_id: other_item.id, quantity: "1" } } } }
    end
    assert_response :unprocessable_entity
    assert_match(/no longer available/, response.body)

    assert_no_difference("Order.count") do
      post staff_orders_path, params: { order: { customer_name: "Taylor", order_items_attributes: { "0" => { menu_item_id: @menu_item.id, quantity: "0" } } } }
    end
    assert_response :unprocessable_entity
    assert_match(/Select at least one menu item/, response.body)
  end

  test "order creation rejects invalid quantities and missing customer names" do
    sign_in_as(@staff)

    [ "-1", "invalid" ].each do |quantity|
      assert_no_difference("Order.count") do
        post staff_orders_path, params: {
          order: {
            customer_name: "Taylor",
            order_items_attributes: { "0" => { menu_item_id: @menu_item.id, quantity: quantity } }
          }
        }
      end
      assert_response :unprocessable_entity
    end

    assert_no_difference("Order.count") do
      post staff_orders_path, params: {
        order: {
          customer_name: "",
          order_items_attributes: { "0" => { menu_item_id: @menu_item.id, quantity: "1" } }
        }
      }
    end
    assert_response :unprocessable_entity
    assert_select '[role="alert"]'
  end

  test "order creation rejects duplicate item rows" do
    sign_in_as(@staff)
    duplicate_rows = {
      "0" => { menu_item_id: @menu_item.id, quantity: "1" },
      "1" => { menu_item_id: @menu_item.id, quantity: "2" }
    }

    assert_no_difference("Order.count") do
      post staff_orders_path, params: { order: { customer_name: "Taylor", order_items_attributes: duplicate_rows } }
    end

    assert_response :unprocessable_entity
    assert_match(/only be selected once/, response.body)
  end

  test "staff can advance and cancel orders but completed orders are terminal" do
    sign_in_as(@staff)
    order = create_order(status: :pending)

    patch advance_staff_order_path(order)
    assert_equal "preparing", order.reload.status
    patch cancel_staff_order_path(order)
    assert_equal "cancelled", order.reload.status

    completed_order = create_order(status: :completed)
    patch advance_staff_order_path(completed_order)
    assert_equal "completed", completed_order.reload.status
    assert_match(/cannot be advanced/, flash[:alert])
  end

  private

  def create_order(status:, quantity: 1, created_at: Time.current)
    order = Order.create!(
      restaurant: @restaurant,
      customer_name: "Guest",
      created_by: @staff,
      status: status,
      created_at: created_at
    )
    order.order_items.create!(menu_item: @menu_item, quantity: quantity, unit_price: @menu_item.price)
    order
  end
end
