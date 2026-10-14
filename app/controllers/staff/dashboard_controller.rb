module Staff
  class DashboardController < BaseController
    def show
      restaurant_orders = current_restaurant.orders
      today_orders = restaurant_orders.where(created_at: Time.zone.today.all_day)

      @active_orders_count = restaurant_orders.where(status: %i[pending preparing ready]).count
      @today_orders_count = today_orders.where.not(status: :cancelled).count
      @today_revenue = today_orders.completed.joins(:order_items)
        .sum("order_items.unit_price * order_items.quantity")
      @recent_orders = restaurant_orders.includes(:order_items, :user, :checkout_group)
        .order(created_at: :desc).limit(10)
    end
  end
end
