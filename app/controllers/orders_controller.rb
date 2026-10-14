class OrdersController < ApplicationController
  before_action :require_customer
  before_action :set_order, only: :show

  def index
    @orders = Current.account.orders.includes(checkout_group: :restaurant)
      .order(created_at: :desc)
  end

  def show
  end

  private

  def require_customer
    return if Current.account.is_a?(User) && Current.account.customer?

    redirect_to root_path, alert: "Customer access is required."
  end

  def set_order
    @order = Current.account.orders.includes(:order_items, :restaurant, checkout_group: :checkout).find(params[:id])
  end
end
