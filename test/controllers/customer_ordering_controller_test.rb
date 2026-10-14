require "test_helper"

class CustomerOrderingControllerTest < ActionDispatch::IntegrationTest
  setup do
    @restaurant = Restaurant.create!(name: "Corner Table")
    @menu_item = MenuItem.create!(restaurant: @restaurant, name: "Soup", price: "8.50")
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
