module OrganizationAdmin
  class DashboardController < BaseController
    def show
      orders = Order.joins(:restaurant).where(restaurants: { organization_id: current_organization.id })
      today_orders = orders.where(created_at: Time.zone.today.all_day)

      @restaurants = current_organization.restaurants.order(:name)
      @active_orders_count = orders.where(status: %i[pending preparing ready]).count
      @today_orders_count = today_orders.where.not(status: :cancelled).count
      @today_revenue = today_orders.completed.joins(:order_items)
        .sum("order_items.unit_price * order_items.quantity")
      @recent_orders = orders.includes(:restaurant, :order_items, :user)
        .order(created_at: :desc).limit(10)
    end
  end
end
