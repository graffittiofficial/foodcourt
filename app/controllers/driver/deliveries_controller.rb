module Driver
  class DeliveriesController < BaseController
    before_action :set_order, only: :advance

    def index
      @orders = Current.account.assigned_orders
        .includes(:restaurant, { order_items: :menu_item }, checkout_group: :checkout)
        .order(created_at: :desc)
    end

    def advance
      next_status = {
        "assigned" => :picked_up,
        "picked_up" => :delivered
      }[@order.delivery_status]

      if next_status && @order.update_delivery_status(next_status)
        redirect_to driver_root_path, notice: "Delivery status updated to #{@order.delivery_status.humanize}."
      else
        redirect_to driver_root_path, alert: @order.errors.full_messages.to_sentence.presence || "This delivery cannot be advanced."
      end
    end

    private

    def set_order
      @order = Current.account.assigned_orders.find(params[:id])
    end
  end
end
