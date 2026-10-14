class CheckoutBuilder
  class Error < StandardError; end

  def initialize(user:, entries:, address:, maps: GoogleRoutes, places: GooglePlaces, stripe: StripeGateway.new)
    @user = user
    @entries = entries
    @address = address
    @maps = maps
    @places = places
    @stripe = stripe
  end

  def call(success_url:, cancel_url:)
    validate_entries!
    address = @places.address_for(@address.fetch(:google_place_id)).merge(
      customer_name: @address.fetch(:customer_name),
      customer_phone: @address.fetch(:customer_phone),
      address_line2: @address[:address_line2]
    )
    quotes = build_quotes
    total_cents = quotes.sum do |quote|
      quote.fetch(:delivery_fee).to_d.then { |fee| (fee * 100).round } +
        quote.fetch(:items).sum { |entry| (entry.menu_item.price * entry.quantity * 100).round }
    end

    checkout = Checkout.transaction do
      checkout = Checkout.create!(
        user: @user,
        customer_name: address.fetch(:customer_name),
        customer_phone: address.fetch(:customer_phone),
        address_line1: address.fetch(:address_line1),
        address_line2: address[:address_line2],
        city: address.fetch(:city),
        region: address.fetch(:region),
        postal_code: address.fetch(:postal_code),
        country_code: address.fetch(:country_code),
        google_place_id: address.fetch(:google_place_id),
        total_amount_cents: total_cents,
        currency: "usd"
      )

      quotes.each do |quote|
        group = checkout.checkout_groups.create!(
          restaurant: quote.fetch(:restaurant),
          distance_km: quote.fetch(:distance_km),
          delivery_fee: quote.fetch(:delivery_fee)
        )
        quote.fetch(:items).each do |entry|
          group.checkout_items.create!(
            menu_item: entry.menu_item,
            menu_item_name: entry.menu_item.name,
            quantity: entry.quantity,
            unit_price: entry.menu_item.price
          )
        end
      end
      checkout
    end

    session = @stripe.create_checkout_session(checkout: checkout, success_url: success_url, cancel_url: cancel_url)
    { checkout: checkout, stripe_session: session }
  end

  private

  def validate_entries!
    raise Error, "Your basket is empty." if @entries.empty?

    unavailable = @entries.reject(&:available)
    raise Error, "Remove unavailable menu items before checking out." if unavailable.any?

    if @entries.any? { |entry| entry.quantity.to_i < 1 }
      raise Error, "Every menu item must have a positive quantity."
    end

    raise Error, "Your delivery details are incomplete." if %i[customer_name customer_phone google_place_id].any? { |field| @address[field].blank? }
  end

  def build_quotes
    @entries.group_by { |entry| entry.menu_item.restaurant }.map do |restaurant, items|
      unless restaurant.delivery_configured? && restaurant.stripe_connected?
        raise Error, "#{restaurant.name} is not set up for delivery and online payments yet."
      end

      distance_km = @maps.distance_km(
        origin_place_id: restaurant.google_place_id,
        destination_place_id: @address.fetch(:google_place_id)
      )
      if distance_km > restaurant.max_delivery_distance_km
        raise Error, "#{restaurant.name} cannot deliver to that address."
      end

      {
        restaurant: restaurant,
        distance_km: distance_km,
        delivery_fee: restaurant.delivery_fee_for(distance_km),
        items: items
      }
    end
  end
end
