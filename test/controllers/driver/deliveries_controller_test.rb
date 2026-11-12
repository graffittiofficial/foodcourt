require "test_helper"

class Driver::DeliveriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @restaurant = create_restaurant(name: "Driver Restaurant")
    @driver = User.create!(name: "Delivery Driver", email_address: "deliveries-driver@example.test", password: "password", role: :driver)
    @other_driver = User.create!(name: "Other Driver", email_address: "other-deliveries-driver@example.test", password: "password", role: :driver)
  end

  test "drivers see only their deliveries and can advance an assigned delivery" do
    assigned = create_delivery(driver: @driver, customer_name: "Assigned Customer", delivery_status: :assigned)
    other_delivery = create_delivery(driver: @other_driver, customer_name: "Other Customer", delivery_status: :assigned)
    sign_in_as(@driver)

    get driver_root_path
    assert_response :success
    assert_includes response.body, assigned.customer_name
    assert_not_includes response.body, other_delivery.customer_name

    patch advance_driver_delivery_path(assigned)
    assert_redirected_to driver_root_path
    assert_equal "picked_up", assigned.reload.delivery_status

    patch advance_driver_delivery_path(assigned)
    assert_redirected_to driver_root_path
    assert_equal "delivered", assigned.reload.delivery_status
  end

  test "drivers cannot advance another driver's delivery or advance an unassigned order" do
    assigned_elsewhere = create_delivery(driver: @other_driver, customer_name: "Private Customer", delivery_status: :assigned)
    unassigned = create_delivery(driver: @driver, customer_name: "Unassigned Customer", delivery_status: :unassigned)
    sign_in_as(@driver)

    patch advance_driver_delivery_path(assigned_elsewhere)
    assert_response :not_found

    patch advance_driver_delivery_path(unassigned)
    assert_redirected_to driver_root_path
    assert_match "cannot be advanced", flash[:alert]
    assert_equal "unassigned", unassigned.reload.delivery_status
  end

  private

  def create_delivery(driver:, customer_name:, delivery_status:)
    customer = User.create!(name: customer_name, email_address: "#{SecureRandom.hex(5)}@example.test", password: "password")
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
      total_amount_cents: 1000
    )
    checkout_group = CheckoutGroup.create!(checkout: checkout, restaurant: @restaurant, distance_km: 3, delivery_fee: "2.50")
    menu_item = MenuItem.create!(restaurant: @restaurant, name: "Delivery Item #{SecureRandom.hex(3)}", price: "7.50")
    order = Order.create!(
      restaurant: @restaurant,
      checkout_group: checkout_group,
      user: customer,
      driver: driver,
      customer_name: customer_name,
      delivery_status: delivery_status
    )
    order.order_items.create!(menu_item: menu_item, quantity: 1, unit_price: menu_item.price)
    order
  end
end
