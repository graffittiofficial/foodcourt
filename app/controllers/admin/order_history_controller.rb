module Admin
  class OrderHistoryController < BaseController
    PAGE_SIZE = 25
    DATE_RANGES = { "7" => 7, "30" => 30, "90" => 90 }.freeze

    def index
      return head(:bad_request) unless valid_filters?

      @range = params[:range].presence
      @created_on = params[:created_on].present? ? Date.iso8601(params[:created_on]) : nil
      @status = params[:status].presence
      @delivery_status = params[:delivery_status].presence
      @restaurant_id = params[:restaurant_id].presence
      @query = params[:q].to_s.strip
      @filters_active = [ @query, @range, @created_on, @status, @delivery_status, @restaurant_id ].any?(&:present?)

      orders = Order.includes(:restaurant, :user, :checkout_group, :order_items)
        .order(created_at: :desc, id: :desc)
      if @range
        start_date = Time.zone.today - (DATE_RANGES.fetch(@range) - 1)
        orders = orders.where(created_at: start_date.in_time_zone.beginning_of_day...(Time.zone.tomorrow.beginning_of_day))
      end
      orders = orders.where(created_at: @created_on.in_time_zone.beginning_of_day...(@created_on + 1).in_time_zone.beginning_of_day) if @created_on
      orders = orders.where(status: @status) if @status
      orders = Search::Filter.orders(orders, @query)
      if @delivery_status
        orders = orders.where(checkout_group_id: CheckoutGroup.select(:id), delivery_status: @delivery_status)
      end
      orders = orders.where(restaurant_id: @restaurant_id) if @restaurant_id

      @total_count = orders.count
      @total_pages = [ (@total_count.to_f / PAGE_SIZE).ceil, 1 ].max
      @page = [ page_number, @total_pages ].min
      @orders = orders.limit(PAGE_SIZE).offset((@page - 1) * PAGE_SIZE)
      @query_params = request.query_parameters.except("page")
    rescue ArgumentError, TypeError
      head :bad_request
    end

    private

    def valid_filters?
      return false if params[:range].present? && !DATE_RANGES.key?(params[:range])
      return false if params[:status].present? && !Order.statuses.key?(params[:status])
      return false if params[:delivery_status].present? && !Order.delivery_statuses.key?(params[:delivery_status])
      return false if params[:created_on].present? && !valid_date?(params[:created_on])
      restaurant_id = params[:restaurant_id].to_s
      return false if params[:restaurant_id].present? &&
        (!restaurant_id.match?(/\A[1-9]\d*\z/) || !Restaurant.exists?(id: restaurant_id))

      true
    end

    def valid_date?(value)
      Date.iso8601(value)
      true
    rescue ArgumentError, TypeError
      false
    end

    def page_number
      page = Integer((params[:page].presence || 1).to_s, 10)
      raise ArgumentError unless page.positive?

      page
    end
  end
end
