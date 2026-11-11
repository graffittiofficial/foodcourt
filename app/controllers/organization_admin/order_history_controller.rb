module OrganizationAdmin
  class OrderHistoryController < BaseController
    def index
      @query = params[:q].to_s.strip
      @orders = Search::Filter.orders(
        Order.where(restaurant_id: current_organization.restaurants.select(:id))
          .includes(:restaurant, :driver, :order_items)
          .order(created_at: :desc, id: :desc),
        @query
      ).limit(100)
    end
  end
end
