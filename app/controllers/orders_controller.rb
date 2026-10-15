class OrdersController < ApplicationController
  before_action :require_customer
  before_action :set_order, only: :show

  def index
    @orders = Current.account.orders.includes(
      :order_items,
      { restaurant: :photo_attachment },
      checkout_group: :restaurant
    )
      .order(created_at: :desc)
  end

  def show
    @restaurant_review = @order.reviews.find { |review| review.reviewable_type == "Restaurant" }
    @menu_item_reviews = @order.reviews.select { |review| review.reviewable_type == "MenuItem" }.index_by(&:reviewable_id)
  end

  private

  def require_customer
    return if Current.account.is_a?(User) && Current.account.customer?

    redirect_to root_path, alert: "Customer access is required."
  end

  def set_order
    @order = Current.account.orders.includes(
      :reviews,
      { restaurant: :photo_attachment },
      { order_items: [ menu_item: :photo_attachment ] },
      checkout_group: :checkout
    ).find(params[:id])
  end
end
