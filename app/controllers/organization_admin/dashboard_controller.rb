module OrganizationAdmin
  class DashboardController < BaseController
    def show
      @chart_range = params[:range].presence || "30"
      return head(:bad_request) unless CHART_DATE_RANGES.key?(@chart_range)

      orders = Order.joins(:restaurant).where(restaurants: { organization_id: current_organization.id })
      today_orders = orders.where(created_at: Time.zone.today.all_day)

      @restaurants = current_organization.restaurants.order(:name)
      @restaurant_order_counts = Order.joins(:restaurant)
        .where(restaurants: { organization_id: current_organization.id })
        .group(:restaurant_id).count
      @active_orders_count = orders.where(status: %i[pending preparing ready]).count
      @today_orders_count = today_orders.where.not(status: :cancelled).count
      @today_revenue = today_orders.completed.joins(:order_items)
        .sum("order_items.unit_price * order_items.quantity")
      @recent_orders = orders.includes(:restaurant, :order_items, :user, :checkout_group)
        .order(created_at: :desc).limit(10)

      load_chart_data
    end

    private

    def load_chart_data
      @chart_start_date = Time.zone.today - (CHART_DATE_RANGES.fetch(@chart_range) - 1)
      chart_end_date = Time.zone.today + 1
      chart_period = @chart_start_date.in_time_zone.beginning_of_day...chart_end_date.in_time_zone.beginning_of_day
      date_group = Arel.sql("DATE(orders.created_at)")
      organization_orders = Order.joins(:restaurant)
        .where(restaurants: { organization_id: current_organization.id })
      orders_in_period = organization_orders.where(created_at: chart_period)

      @chart_dates = (@chart_start_date..(chart_end_date - 1)).to_a
      @orders_by_day = @chart_dates.index_with(0)
      orders_in_period.group(date_group).count.each { |date, count| @orders_by_day[date.to_date] = count }

      item_sales = Order.completed.joins(:restaurant)
        .where(restaurants: { organization_id: current_organization.id }, created_at: chart_period)
        .left_joins(:order_items).group(date_group)
        .sum("order_items.unit_price * order_items.quantity")
      delivery_sales = Order.completed.joins(:restaurant, :checkout_group)
        .where(restaurants: { organization_id: current_organization.id }, created_at: chart_period)
        .group(date_group).sum("checkout_groups.delivery_fee")
      @sales_by_day = @chart_dates.index_with do |date|
        (item_sales.fetch(date, 0) || 0) + (delivery_sales.fetch(date, 0) || 0)
      end

      @orders_by_status = Order.statuses.keys.index_with(0)
      orders_in_period.group(:status).count.each { |status, count| @orders_by_status[status] = count }

      @top_restaurants = Order.completed.where(created_at: chart_period)
        .joins(:restaurant)
        .where(restaurants: { organization_id: current_organization.id })
        .group("restaurants.id", "restaurants.name")
        .order(Arel.sql("COUNT(orders.id) DESC"), "restaurants.name")
        .limit(10).count
        .map { |(id, name), count| [ id, name, count ] }
    end
  end
end
