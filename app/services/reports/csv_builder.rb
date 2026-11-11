require "csv"

module Reports
  class CsvBuilder
    ORDER_HEADERS = [ "Order ID", "Order Date", "Order Status", "Delivery Status", "Item Subtotal" ].freeze
    ITEM_HEADERS = [ "Menu Item", "Quantity Sold", "Item Revenue" ].freeze

    def initialize(report)
      @report = report
    end

    def call
      case report.category
      when "finance"
        order_csv(finance_orders)
      when "operations"
        order_csv(orders)
      when "kitchen_product"
        item_csv
      else
        raise ArgumentError, "Unsupported report category: #{report.category.inspect}"
      end
    end

    private

    attr_reader :report

    def orders
      @orders ||= begin
        order_scope.includes(:order_items)
          .where(created_at: date_range)
          .order(:created_at, :id)
      end
    end

    def finance_orders
      orders.where(status: "completed", refunded_at: nil)
    end

    def order_csv(selected_orders)
      CSV.generate(row_sep: "\r\n") do |csv|
        csv << ORDER_HEADERS
        selected_orders.find_each do |order|
          csv << [
            order.id,
            order.created_at.in_time_zone(report.organization.time_zone).to_date.iso8601,
            order.status,
            order.delivery_status,
            currency(order.order_items.sum { |item| item.unit_price * item.quantity })
          ]
        end
      end
    end

    def item_csv
      CSV.generate(row_sep: "\r\n") do |csv|
        csv << ITEM_HEADERS
        item_totals.each do |name, quantity, revenue|
          csv << [
            safe_cell(name),
            quantity,
            currency(revenue)
          ]
        end
      end
    end

    def item_totals
      order_scope.where(created_at: date_range, status: "completed", refunded_at: nil)
        .joins(:order_items)
        .group("order_items.menu_item_name")
        .order("order_items.menu_item_name")
        .pluck(
          "order_items.menu_item_name",
          Arel.sql("SUM(order_items.quantity)"),
          Arel.sql("SUM(order_items.unit_price * order_items.quantity)")
        )
    end

    def order_scope
      report.restaurant ? report.restaurant.orders : Order.joins(:restaurant)
        .where(restaurants: { organization_id: report.organization_id })
    end

    def date_range
      start_time = report.start_date.in_time_zone(report.organization.time_zone).beginning_of_day
      end_time = (report.end_date + 1.day).in_time_zone(report.organization.time_zone).beginning_of_day
      start_time...end_time
    end

    def currency(amount)
      format("%.2f", amount)
    end

    def safe_cell(value)
      text = value.to_s
      text.match?(/\A\s*[=+\-@]/) ? "'#{text}" : text
    end
  end
end
