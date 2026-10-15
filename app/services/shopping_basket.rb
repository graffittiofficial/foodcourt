class ShoppingBasket
  Entry = Data.define(:menu_item, :item_id, :quantity, :available)

  def initialize(session:, user: nil)
    @session = session
    @user = user if user.is_a?(User) && user.customer?
  end

  def entries
    synchronize_guest_items if user

    persisted_entries = if user&.cart
      user.cart.cart_items.includes(menu_item: :photo_attachment).map do |item|
        Entry.new(menu_item: item.menu_item, item_id: item.menu_item_id, quantity: item.quantity, available: item.menu_item.available? && item.menu_item.archived_at.nil?)
      end
    else
      []
    end

    guest_entries = basket_hash.filter_map do |item_id, quantity|
      menu_item = MenuItem.with_attached_photo.find_by(id: item_id)
      Entry.new(
        menu_item: menu_item,
        item_id: item_id.to_i,
        quantity: quantity,
        available: menu_item.present? && menu_item.available? && menu_item.archived_at.nil?
      )
    end

    persisted_entries + guest_entries
  end

  def add(menu_item, quantity)
    raise ArgumentError, "Quantity must be a positive integer" unless quantity.to_s.match?(/\A[1-9]\d*\z/)

    if user
      user_cart.add_item(menu_item, quantity)
    else
      basket_hash[menu_item.id.to_s] = basket_hash.fetch(menu_item.id.to_s, 0) + quantity.to_i
      persist_basket
      true
    end
  end

  def remove(item_id)
    if user
      user.cart&.cart_items&.find_by(menu_item_id: item_id)&.destroy!
    end

    basket_hash.delete(item_id.to_s)
    persist_basket
  end

  def update(menu_item, quantity)
    raise ArgumentError, "Quantity must be zero or a positive integer" unless quantity.to_s.match?(/\A(?:0|[1-9]\d*)\z/)

    if quantity.to_i.zero?
      remove(menu_item.id)
    elsif user
      item = user_cart.cart_items.find_or_initialize_by(menu_item: menu_item)
      item.update!(quantity: quantity.to_i)
    else
      basket_hash[menu_item.id.to_s] = quantity.to_i
      persist_basket
    end
  end

  def clear
    user&.cart&.cart_items&.destroy_all
    @session.delete(:basket)
  end

  def active_entries
    entries.select(&:available)
  end

  def unavailable_entries
    entries.reject(&:available)
  end

  private

  attr_reader :session, :user

  def user_cart
    user.cart || user.create_cart!
  end

  def synchronize_guest_items
    return if basket_hash.empty?

    cart = user_cart
    stale_ids = []
    cart.with_lock do
      basket_hash.each do |item_id, quantity|
        menu_item = MenuItem.available.find_by(id: item_id)
        unless menu_item
          stale_ids << item_id
          next
        end

        cart.add_item(menu_item, quantity)
      end
    end
    basket_hash.except!(*(basket_hash.keys - stale_ids))
    persist_basket
  end

  def basket_hash
    @basket_hash ||= begin
      value = session[:basket]
      value.is_a?(Hash) ? value.each_with_object({}) do |(item_id, quantity), basket|
        next unless item_id.to_s.match?(/\A\d+\z/) && quantity.to_s.match?(/\A[1-9]\d*\z/)

        basket[item_id.to_s] = quantity.to_i
      end : {}
    end
  end

  def persist_basket
    basket_hash.empty? ? session.delete(:basket) : session[:basket] = basket_hash
  end
end
