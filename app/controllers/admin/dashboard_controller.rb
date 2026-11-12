module Admin
  class DashboardController < BaseController
    DATE_RANGES = { "7" => 7, "30" => 30, "90" => 90 }.freeze

    def show
      @chart_range = params[:range].presence || "30"
      return head(:bad_request) unless DATE_RANGES.key?(@chart_range)

      @user_count = User.count
      @restaurant_count = Restaurant.count
      @menu_item_count = MenuItem.count

      load_chart_data

      completed_orders = Order.completed
      today_orders = Order.where(created_at: Time.zone.today.all_day)
      @all_time_sales_count = completed_orders.count
      @all_time_revenue = revenue_for(completed_orders)
      @today_order_count = today_orders.where.not(status: :cancelled).count
      @today_revenue = revenue_for(today_orders.completed)

      @pending_orders = Order.includes(:restaurant)
        .pending
        .order(created_at: :asc)
        .limit(6)
      @unassigned_orders = Order.includes(:restaurant, :checkout_group)
        .where(delivery_status: :unassigned)
        .where.not(checkout_group_id: nil)
        .where.not(status: :cancelled)
        .order(created_at: :asc)
        .limit(6)
      @restaurants_needing_setup = Restaurant.where(incomplete_setup_conditions)
        .order(:name)
        .limit(6)
      @restaurants_needing_setup_count = Restaurant.where(incomplete_setup_conditions).count
      @recent_orders = Order.includes(:user, :restaurant, :order_items, :checkout_group)
        .order(created_at: :desc)
        .limit(8)
    end

    private

    def load_chart_data
      @chart_start_date = Time.zone.today - (DATE_RANGES.fetch(@chart_range) - 1)
      chart_end_date = Time.zone.today + 1
      chart_period = @chart_start_date.in_time_zone.beginning_of_day...chart_end_date.in_time_zone.beginning_of_day
      date_group = Arel.sql("DATE(orders.created_at)")
      orders_in_period = Order.where(created_at: chart_period)

      @chart_dates = (@chart_start_date..(chart_end_date - 1)).to_a
      @orders_by_day = @chart_dates.index_with(0)
      orders_in_period.group(date_group).count.each { |date, count| @orders_by_day[date.to_date] = count }

      item_sales = Order.completed.where(created_at: chart_period)
        .left_joins(:order_items).group(date_group)
        .sum("order_items.unit_price * order_items.quantity")
      delivery_sales = Order.completed.where(created_at: chart_period)
        .joins(:checkout_group).group(date_group)
        .sum("checkout_groups.delivery_fee")
      @sales_by_day = @chart_dates.index_with do |date|
        (item_sales.fetch(date, 0) || 0) + (delivery_sales.fetch(date, 0) || 0)
      end

      @orders_by_status = Order.statuses.keys.index_with(0)
      orders_in_period.group(:status).count.each { |status, count| @orders_by_status[status] = count }

      @deliveries_by_status = Order.delivery_statuses.keys.index_with(0)
      orders_in_period.where.not(checkout_group_id: nil).group(:delivery_status).count
        .each { |status, count| @deliveries_by_status[status] = count }

      @top_restaurants = Order.completed.where(created_at: chart_period)
        .joins(:restaurant).group("restaurants.id", "restaurants.name")
        .order(Arel.sql("COUNT(orders.id) DESC"), "restaurants.name")
        .limit(10).count
        .map { |(id, name), count| [ id, name, count ] }
    end

    def revenue_for(orders)
      item_subtotal = orders.joins(:order_items).sum("order_items.unit_price * order_items.quantity")
      delivery_fees = orders.joins(:checkout_group).sum("checkout_groups.delivery_fee")

      item_subtotal + delivery_fees
    end

    def incomplete_setup_conditions
      delivery_text_fields = %w[address_line1 city region postal_code country_code google_place_id]
      delivery_text_fields = delivery_text_fields.map do |field|
        "#{field} IS NULL OR #{field} = ''"
      end.join(" OR ")
      delivery_numeric_fields = %w[delivery_base_fee delivery_fee_per_km max_delivery_distance_km]
      missing_delivery_numeric_field = delivery_numeric_fields.map { |field| "#{field} IS NULL" }.join(" OR ")

      "stripe_account_id IS NULL OR stripe_account_id = '' OR " \
        "stripe_account_onboarded_at IS NULL OR #{delivery_text_fields} OR #{missing_delivery_numeric_field}"
    end
  end
end
