module Admin
  class DashboardController < BaseController
    def show
      @user_count = User.count
      @restaurant_count = Restaurant.count
      @menu_item_count = MenuItem.count

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
