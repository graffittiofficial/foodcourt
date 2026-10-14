class StripeGateway
  class Error < StandardError; end
  class ConfigurationError < Error; end

  def create_checkout_session(checkout:, success_url:, cancel_url:)
    response = client.v1.checkout.sessions.create(
      {
        mode: "payment",
        payment_method_types: [ "card" ],
        customer_email: checkout.user.email_address,
        client_reference_id: checkout.id.to_s,
        line_items: checkout_groups_line_items(checkout),
        payment_intent_data: {
          transfer_group: transfer_group(checkout),
          metadata: { checkout_id: checkout.id.to_s }
        },
        success_url: success_url,
        cancel_url: cancel_url
      },
      { idempotency_key: "foodcourt-checkout-#{checkout.id}" }
    )
    checkout.update!(stripe_checkout_session_id: response.id)
    response
  end

  def create_express_account(restaurant)
    client.v1.accounts.create(
      {
        type: "express",
        country: restaurant.country_code.upcase,
        capabilities: { transfers: { requested: true } },
        business_profile: { name: restaurant.name }
      }
    )
  end

  def create_account_link(restaurant:, refresh_url:, return_url:)
    client.v1.account_links.create(
      {
        account: restaurant.stripe_account_id,
        refresh_url: refresh_url,
        return_url: return_url,
        type: "account_onboarding"
      }
    )
  end

  def retrieve_account(restaurant)
    client.v1.accounts.retrieve(restaurant.stripe_account_id)
  end

  def charge_id_for(payment_intent_id)
    payment_intent = client.v1.payment_intents.retrieve(payment_intent_id, { expand: [ "latest_charge" ] })
    charge = payment_intent.latest_charge
    charge = charge.id if charge.respond_to?(:id)
    raise StripeGateway::Error, "Stripe payment intent has no successful charge" if charge.blank?

    charge
  end

  def transfer_order!(order)
    group = order.checkout_group
    group.with_lock do
      return if group.stripe_transfer_id.present?

      transfer = client.v1.transfers.create(
        {
          amount: group.total_amount_cents,
          currency: group.checkout.currency,
          destination: order.restaurant.stripe_account_id,
          source_transaction: group.checkout.stripe_charge_id,
          transfer_group: transfer_group(group.checkout),
          metadata: { order_id: order.id.to_s, restaurant_id: order.restaurant_id.to_s }
        },
        { idempotency_key: "foodcourt-order-transfer-#{order.id}" }
      )
      group.update!(stripe_transfer_id: transfer.id)
    end
  end

  def refund_order!(order)
    group = order.checkout_group
    raise ConfigurationError, "Order has no Stripe payment or transfer" unless group&.stripe_transfer_id.present?

    refund = client.v1.refunds.create(
      {
        payment_intent: group.checkout.stripe_payment_intent_id,
        amount: group.total_amount_cents
      },
      { idempotency_key: "foodcourt-order-refund-#{order.id}" }
    )
    reversal = client.v1.transfers.reversals.create(
      group.stripe_transfer_id,
      { amount: group.total_amount_cents },
      { idempotency_key: "foodcourt-order-reversal-#{order.id}" }
    )
    group.update!(stripe_refund_id: refund.id, stripe_transfer_reversal_id: reversal.id)
  end

  private

  def client
    @client ||= Stripe::StripeClient.new(ENV.fetch("STRIPE_SECRET_KEY") do
      raise ConfigurationError, "Stripe secret key is not configured"
    end)
  end

  def checkout_groups_line_items(checkout)
    checkout.checkout_groups.includes(:restaurant, :checkout_items).flat_map do |group|
      item_lines = group.checkout_items.map do |item|
        {
          price_data: {
            currency: checkout.currency,
            product_data: { name: "#{item.menu_item_name} - #{group.restaurant.name}" },
            unit_amount: (item.unit_price * 100).round
          },
          quantity: item.quantity
        }
      end
      next item_lines if group.delivery_fee.zero?

      item_lines << {
        price_data: {
          currency: checkout.currency,
          product_data: { name: "Delivery - #{group.restaurant.name}" },
          unit_amount: (group.delivery_fee * 100).round
        },
        quantity: 1
      }
    end
  end

  def transfer_group(checkout)
    "foodcourt_checkout_#{checkout.id}"
  end
end
