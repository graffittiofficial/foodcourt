require "test_helper"
require "csv"

class Reports::CsvBuilderTest < ActiveSupport::TestCase
  setup do
    @organization = create_organization
    @restaurant = create_restaurant(name: "Test Restaurant", organization: @organization)
    @requester = User.create!(email_address: "reports@example.test", password: "password")
    OrganizationMembership.create!(organization: @organization, user: @requester)
  end

  test "finance CSV includes only completed non-refunded item subtotals" do
    included = create_order(status: "completed", created_at: Time.zone.local(2026, 10, 4, 12))
    add_item(included, "Soup", quantity: 2, unit_price: 4.25)
    refunded = create_order(status: "completed", refunded_at: Time.zone.local(2026, 10, 4, 13))
    add_item(refunded, "Pie", quantity: 1, unit_price: 8)
    create_order(status: "cancelled")

    csv = CSV.parse(build_report("finance").generate_csv)

    assert_equal [ "Order ID", "Order Date", "Order Status", "Delivery Status", "Item Subtotal" ], csv.first
    assert_equal [ included.id.to_s, "2026-10-04", "completed", "unassigned", "8.50" ], csv.second
    assert_equal 2, csv.length
  end

  test "operations CSV includes canceled and refunded orders with fulfillment statuses" do
    order = create_order(status: "cancelled", delivery_status: "picked_up", refunded_at: Time.zone.now)
    add_item(order, "Soup", quantity: 1, unit_price: 3.5)

    csv = CSV.parse(build_report("operations").generate_csv)

    assert_equal [ "Order ID", "Order Date", "Order Status", "Delivery Status", "Item Subtotal" ], csv.first
    assert_equal [ order.id.to_s, order.created_at.in_time_zone(@organization.time_zone).to_date.iso8601,
      "cancelled", "picked_up", "3.50" ], csv.second
  end

  test "item performance aggregates completed non-refunded items by snapshotted name" do
    completed = create_order(status: "completed")
    add_item(completed, "Soup", quantity: 2, unit_price: 4.25)
    another_completed = create_order(status: "completed")
    add_item(another_completed, "Soup", quantity: 1, unit_price: 4.5)
    refunded = create_order(status: "completed", refunded_at: Time.zone.now)
    add_item(refunded, "Soup", quantity: 10, unit_price: 4.25)
    create_order(status: "preparing")

    csv = CSV.parse(build_report("kitchen_product").generate_csv)

    assert_equal [ "Menu Item", "Quantity Sold", "Item Revenue" ], csv.first
    assert_equal [ "Soup", "3", "13.00" ], csv.second
    assert_equal 2, csv.length
  end

  test "item names are escaped to prevent spreadsheet formula execution" do
    order = create_order(status: "completed")
    add_item(order, "=1+1", quantity: 1, unit_price: 2)

    csv = CSV.parse(build_report("kitchen_product").generate_csv)

    assert_equal "'=1+1", csv.second.first
  end

  private

  def build_report(category)
    Report.new(
      requester: @requester,
      organization: @organization,
      restaurant: @restaurant,
      category: category,
      status: "queued",
      start_date: Date.new(2026, 10, 1),
      end_date: Date.new(2026, 10, 31)
    )
  end

  def create_order(status:, created_at: Time.zone.local(2026, 10, 4, 12), delivery_status: "unassigned", refunded_at: nil)
    @restaurant.orders.create!(
      customer_name: "Report test customer",
      status: status,
      delivery_status: delivery_status,
      refunded_at: refunded_at,
      created_at: created_at
    )
  end

  def add_item(order, name, quantity:, unit_price:)
    menu_item = @restaurant.menu_items.find_or_create_by!(name: name) do |item|
      item.price = unit_price
    end
    order.order_items.create!(menu_item: menu_item, quantity: quantity, unit_price: unit_price)
  end
end
