class FulfillCheckout
  class Error < StandardError; end

  def initialize(checkout:, stripe_session:, stripe: StripeGateway.new)
    @checkout = checkout
    @stripe_session = stripe_session
    @stripe = stripe
  end

  def call
    return unless paid_session?

    verify_amount!
    intent_id = payment_intent_id
    charge_id = @stripe.charge_id_for(intent_id)
    @checkout.mark_paid!(payment_intent_id: intent_id, charge_id: charge_id)
    create_orders!
    @checkout.checkout_groups.includes(:order).each do |group|
      @stripe.transfer_order!(group.order)
    end
    remove_ordered_items_from_cart
  end

  private

  def paid_session?
    @stripe_session.payment_status == "paid"
  end

  def verify_amount!
    unless @stripe_session.amount_total == @checkout.total_amount_cents &&
        @stripe_session.currency == @checkout.currency
      raise Error, "Stripe checkout amount does not match the saved order quote."
    end
  end

  def payment_intent_id
    intent = @stripe_session.payment_intent
    intent = intent.id if intent.respond_to?(:id)
    raise Error, "Stripe checkout has no payment intent." if intent.blank?

    intent
  end

  def create_orders!
    Checkout.transaction do
      @checkout.with_lock do
        @checkout.checkout_groups.includes(:restaurant, :checkout_items).each do |group|
          next if group.order

          order = Order.create!(
            checkout_group: group,
            restaurant: group.restaurant,
            user: @checkout.user,
            customer_name: @checkout.customer_name
          )
          group.checkout_items.each do |item|
            order.order_items.create!(
              menu_item: item.menu_item,
              menu_item_name: item.menu_item_name,
              quantity: item.quantity,
              unit_price: item.unit_price
            )
          end
        end
      end
    end
  end

  def remove_ordered_items_from_cart
    cart = @checkout.user.cart
    return unless cart

    cart.with_lock do
      @checkout.checkout_items.each do |checkout_item|
        cart_item = cart.cart_items.find_by(menu_item_id: checkout_item.menu_item_id)
        next unless cart_item

        remaining = cart_item.quantity - checkout_item.quantity
        remaining.positive? ? cart_item.update!(quantity: remaining) : cart_item.destroy!
      end
    end
  end
end
