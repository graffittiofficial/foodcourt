module Admin
  class DashboardController < BaseController
    def show
      @user_count = User.count
      @restaurant_count = Restaurant.count
      @menu_item_count = MenuItem.count
      @order_count = Order.count
      @orders_by_status = Order.group(:status).count
      @recent_orders = Order.includes(:user, :restaurant, :order_items).order(created_at: :desc).limit(8)
    end
  end
end
