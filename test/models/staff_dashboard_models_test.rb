require "test_helper"

class StaffDashboardModelsTest < ActiveSupport::TestCase
  setup do
    @restaurant = Restaurant.create!(name: "Bistro")
    @staff = User.create!(
      email_address: "staff@example.com",
      password: "password",
      role: :staff,
      restaurant: @restaurant
    )
  end

  test "staff users must belong to a restaurant" do
    staff_user = User.new(email_address: "orphan@example.com", password: "password", role: :staff)

    assert_not staff_user.valid?
    assert_includes staff_user.errors[:restaurant], "can't be blank"
  end

  test "customers cannot be assigned a restaurant" do
    customer = User.new(email_address: "customer@example.com", password: "password", restaurant: @restaurant)

    assert_not customer.valid?
    assert_includes customer.errors[:restaurant], "must be blank"
  end

  test "staff order totals use the stored unit price and quantity" do
    menu_item = MenuItem.create!(restaurant: @restaurant, name: "Soup", price: 4.50)
    order = Order.create!(restaurant: @restaurant, customer_name: "Sam", created_by: @staff)
    order.order_items.create!(menu_item: menu_item, quantity: 2, unit_price: 4.25)
    order.order_items.create!(menu_item: MenuItem.create!(restaurant: @restaurant, name: "Bread", price: 2), quantity: 1)

    assert_equal BigDecimal("10.50"), order.total
  end

  test "orders can advance sequentially and terminal states cannot be changed" do
    order = Order.create!(restaurant: @restaurant, customer_name: "Sam", created_by: @staff)

    assert order.advance_status
    assert_equal "preparing", order.status
    assert order.advance_status
    assert_equal "ready", order.status
    assert order.advance_status
    assert_equal "completed", order.status
    assert_not order.advance_status
    assert_not order.cancel
    assert_equal "completed", order.reload.status
  end

  test "orders can be cancelled before completion but not after" do
    order = Order.create!(restaurant: @restaurant, customer_name: "Sam", created_by: @staff)

    assert order.cancel
    assert_equal "cancelled", order.status
    assert_not order.advance_status

    completed_order = Order.create!(restaurant: @restaurant, customer_name: "Alex", created_by: @staff, status: :completed)
    assert_not completed_order.cancel
    assert_equal "completed", completed_order.reload.status
  end

  test "staff order creator must belong to the same restaurant" do
    other_restaurant = Restaurant.create!(name: "Other Bistro")
    order = Order.new(restaurant: @restaurant, customer_name: "Sam", created_by: User.create!(
      email_address: "other-staff@example.com",
      password: "password",
      role: :staff,
      restaurant: other_restaurant
    ))

    assert_not order.valid?
    assert_includes order.errors[:created_by], "must be staff for this restaurant"
  end

  test "archived menu item names can be reused, but active names must be unique" do
    archived_item = MenuItem.create!(restaurant: @restaurant, name: "Soup", price: 4)
    archived_item.update!(archived_at: Time.current, available: false)

    replacement = MenuItem.new(restaurant: @restaurant, name: "Soup", price: 5)
    assert replacement.valid?

    replacement.save!
    duplicate = MenuItem.new(restaurant: @restaurant, name: "Soup", price: 6)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "unavailable and archived menu items cannot be added to a cart" do
    customer = User.create!(email_address: "buyer@example.com", password: "password")
    cart = Cart.create!(user: customer)
    menu_item = MenuItem.create!(restaurant: @restaurant, name: "Soup", price: 4, available: false)
    cart_item = CartItem.new(cart: cart, menu_item: menu_item, quantity: 1)

    assert_not cart_item.valid?
    assert_includes cart_item.errors[:menu_item], "is not available"

    menu_item.update!(available: true, archived_at: Time.current)
    cart_item = CartItem.new(cart: cart, menu_item: menu_item, quantity: 1)
    assert_not cart_item.valid?
  end

  test "direct status changes cannot skip order workflow steps" do
    order = Order.create!(restaurant: @restaurant, customer_name: "Sam", created_by: @staff)

    assert_not order.update(status: :completed)
    assert_includes order.errors[:status], "cannot transition from pending to completed"
    assert_equal "pending", order.reload.status
  end
end
