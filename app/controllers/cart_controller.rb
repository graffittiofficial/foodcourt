class CartController < ApplicationController
  allow_unauthenticated_access

  def show
    @basket = basket
    @entries = @basket.entries
    @total = @basket.active_entries.sum { |entry| entry.menu_item.price * entry.quantity }
  end

  def add_item
    menu_item = MenuItem.available.find(params[:menu_item_id])
    basket.add(menu_item, params[:quantity].presence || "1")
    redirect_back fallback_location: restaurant_path(menu_item.restaurant), notice: "Added to your basket."
  rescue ArgumentError, ActiveRecord::RecordInvalid => error
    redirect_back fallback_location: root_path, alert: error.message
  end

  def update_item
    quantity = params[:quantity]
    if quantity.to_s == "0"
      basket.remove(params[:menu_item_id])
      redirect_to cart_path, notice: "Removed from your basket."
    else
      menu_item = MenuItem.available.find(params[:menu_item_id])
      basket.update(menu_item, quantity)
      redirect_to cart_path, notice: "Basket updated."
    end
  rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
    redirect_to cart_path, alert: error.message
  end

  def remove_item
    basket.remove(params[:menu_item_id])
    redirect_to cart_path, notice: "Removed from your basket."
  end

  private

  def basket
    ShoppingBasket.new(session: session, user: Current.account)
  end
end
