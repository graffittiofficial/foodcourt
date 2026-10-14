require "test_helper"

class MarketplaceCheckoutTest < ActiveSupport::TestCase
  class FakePlaces
    def self.address_for(place_id)
      {
        google_place_id: place_id,
        address_line1: "100 Main Street",
        city: "Townsville",
        region: "CA",
        postal_code: "90210",
        country_code: "US"
      }
    end
  end

  class FakeRoutes
    def self.distance_km(origin_place_id:, destination_place_id:)
      origin_place_id == "restaurant-place-1" ? BigDecimal("3.5") : BigDecimal("2.0")
    end
  end

  class FakeStripe
    def create_checkout_session(checkout:, **)
      checkout.update!(stripe_checkout_session_id: "cs_test_#{checkout.id}")
      Struct.new(:url).new("https://checkout.example.test/session")
    end

    def transfer_order!(order)
      group = order.checkout_group
      group.update!(stripe_transfer_id: "tr_test_#{order.id}") if group.stripe_transfer_id.blank?
    end

    def charge_id_for(payment_intent_id)
      "ch_#{payment_intent_id}"
    end

    def refund_order!(order)
      group = order.checkout_group
      group.update!(
        stripe_refund_id: "re_test_#{order.id}",
        stripe_transfer_reversal_id: "trr_test_#{order.id}"
      )
    end
  end

  StripeSession = Data.define(:payment_status, :amount_total, :currency, :payment_intent)

  setup do
    @customer = User.create!(name: "Taylor Customer", email_address: "taylor@example.test", password: "password")
    @restaurant_one = delivery_ready_restaurant("Corner Table", "restaurant-place-1", "1.50", "0.50")
    @restaurant_two = delivery_ready_restaurant("Little Napoli", "restaurant-place-2", "2.00", "0.25")
    @soup = MenuItem.create!(restaurant: @restaurant_one, name: "Soup", price: "10.00")
    @pizza = MenuItem.create!(restaurant: @restaurant_two, name: "Pizza", price: "5.00")
    @cart = Cart.create!(user: @customer)
    @cart.add_item(@soup, 2)
    @cart.add_item(@pizza, 1)
    @entries = ShoppingBasket.new(session: {}, user: @customer).entries
    @stripe = FakeStripe.new
  end

  test "one paid checkout snapshots items and delivery fees into restaurant-specific orders" do
    result = build_checkout
    checkout = result.fetch(:checkout)

    assert_equal 2, checkout.checkout_groups.count
    assert_equal 3_075, checkout.total_amount_cents
    assert_equal "https://checkout.example.test/session", result.fetch(:stripe_session).url

    @soup.update!(price: "20.00")
    @soup.update!(name: "Updated Soup")
    session = StripeSession.new(
      payment_status: "paid",
      amount_total: 3_075,
      currency: "usd",
      payment_intent: "pi_test_checkout"
    )

    assert_difference("Order.count", 2) do
      FulfillCheckout.new(checkout: checkout, stripe_session: session, stripe: @stripe).call
    end

    assert checkout.reload.paid?
    assert_equal "ch_pi_test_checkout", checkout.stripe_charge_id
    soup_order = checkout.checkout_groups.find_by!(restaurant: @restaurant_one).order
    pizza_order = checkout.checkout_groups.find_by!(restaurant: @restaurant_two).order
    assert_equal BigDecimal("23.25"), soup_order.total
    assert_equal BigDecimal("7.50"), pizza_order.total
    assert_equal BigDecimal("10.00"), soup_order.order_items.sole.unit_price
    assert_equal "Soup", soup_order.order_items.sole.menu_item_name
    assert_equal @customer, soup_order.user
    assert_equal "unassigned", soup_order.delivery_status
    assert_equal 0, @cart.cart_items.count

    assert_no_difference("Order.count") do
      FulfillCheckout.new(checkout: checkout, stripe_session: session, stripe: @stripe).call
    end
  end

  test "checkout rejects a restaurant outside the delivery radius before creating a payment" do
    far_routes = Class.new do
      def self.distance_km(**)
        BigDecimal("100")
      end
    end
    builder = CheckoutBuilder.new(
      user: @customer,
      entries: @entries,
      address: delivery_address,
      maps: far_routes,
      places: FakePlaces,
      stripe: @stripe
    )

    assert_no_difference("Checkout.count") do
      error = assert_raises(CheckoutBuilder::Error) do
        builder.call(success_url: "https://foodcourt.test/success", cancel_url: "https://foodcourt.test/cart")
      end
      assert_match(/cannot deliver/, error.message)
    end
  end

  test "customer basket quantities can be updated without changing guest basket behavior" do
    basket = ShoppingBasket.new(session: {}, user: @customer)
    basket.update(@soup, 4)

    assert_equal 4, @cart.cart_items.find_by!(menu_item: @soup).quantity
    basket.update(@soup, 0)
    assert_not @cart.cart_items.exists?(menu_item: @soup)

    guest_session = { basket: { @soup.id.to_s => 2 } }
    guest_basket = ShoppingBasket.new(session: guest_session)
    guest_basket.update(@soup, 3)
    assert_equal 3, guest_basket.entries.sole.quantity
  end

  test "drivers can advance only their assigned delivery through milestones" do
    checkout = build_checkout.fetch(:checkout)
    FulfillCheckout.new(
      checkout: checkout,
      stripe_session: StripeSession.new(payment_status: "paid", amount_total: 3_075, currency: "usd", payment_intent: "pi_test"),
      stripe: @stripe
    ).call
    order = checkout.checkout_groups.first.order
    driver = User.create!(
      name: "Delivery Driver",
      email_address: "driver@example.test",
      password: "password",
      role: :driver
    )

    assert order.update(driver: driver, delivery_status: :assigned)
    assert order.update_delivery_status(:picked_up)
    assert order.update_delivery_status(:delivered)
    assert_not order.update_delivery_status(:picked_up)
    assert_equal "delivered", order.reload.delivery_status
  end

  test "failed refunds do not cancel a paid restaurant order" do
    checkout = build_checkout.fetch(:checkout)
    FulfillCheckout.new(
      checkout: checkout,
      stripe_session: StripeSession.new(payment_status: "paid", amount_total: 3_075, currency: "usd", payment_intent: "pi_test"),
      stripe: @stripe
    ).call
    order = checkout.checkout_groups.first.order
    failing_stripe = Object.new
    failing_stripe.define_singleton_method(:refund_order!) do |_order|
      raise StripeGateway::Error, "refund unavailable"
    end

    assert_raises(StripeGateway::Error) do
      RefundOrder.new(order: order, stripe: failing_stripe).call
    end

    assert order.reload.pending?
    assert_nil order.refunded_at
  end

  private

  def build_checkout
    CheckoutBuilder.new(
      user: @customer,
      entries: @entries,
      address: delivery_address,
      maps: FakeRoutes,
      places: FakePlaces,
      stripe: @stripe
    ).call(
      success_url: "https://foodcourt.test/checkout/success",
      cancel_url: "https://foodcourt.test/cart"
    )
  end

  def delivery_address
    {
      customer_name: "Taylor Customer",
      customer_phone: "+15555550123",
      google_place_id: "customer-place"
    }
  end

  def delivery_ready_restaurant(name, place_id, base_fee, per_km_fee)
    Restaurant.create!(
      name: name,
      address_line1: "1 Restaurant Way",
      city: "Townsville",
      region: "CA",
      postal_code: "90210",
      country_code: "US",
      google_place_id: place_id,
      stripe_account_id: "acct_#{place_id}",
      stripe_account_onboarded_at: Time.current,
      delivery_base_fee: base_fee,
      delivery_fee_per_km: per_km_fee,
      max_delivery_distance_km: "25"
    )
  end
end
