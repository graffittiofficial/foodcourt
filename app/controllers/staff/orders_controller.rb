module Staff
  class OrdersController < BaseController
    before_action :set_order, only: %i[show advance cancel]

    def index
      @orders = current_restaurant.orders.includes(:order_items, :user)
        .includes(:checkout_group)
        .order(created_at: :desc)
    end

    def show
    end

    def new
      @order = current_restaurant.orders.new
      load_available_menu_items
    end

    def create
      @order = current_restaurant.orders.new(customer_name: order_params[:customer_name], created_by: Current.user)
      build_order_items(order_params[:order_items_attributes])

      if @order.order_items.empty?
        @order.errors.add(:base, "Select at least one menu item.")
      elsif @order.errors.empty? && @order.save
        redirect_to staff_order_path(@order), notice: "Order created."
        return
      end

      load_available_menu_items
      render :new, status: :unprocessable_entity
    end

    def advance
      if @order.advance_status
        redirect_to staff_order_path(@order), notice: "Order advanced to #{@order.status.humanize}."
      else
        redirect_to staff_order_path(@order), alert: @order.errors.full_messages.to_sentence
      end
    end

    def cancel
      cancelled = if @order.checkout_group
        RefundOrder.new(order: @order).call
      else
        @order.cancel
      end

      if cancelled
        redirect_to staff_order_path(@order), notice: "Order cancelled."
      else
        redirect_to staff_order_path(@order), alert: @order.errors.full_messages.to_sentence
      end
    rescue RefundOrder::Error, StripeGateway::ConfigurationError, Stripe::StripeError => error
      Rails.logger.error("Order cancellation failed for order #{@order.id}: #{error.class}: #{error.message}")
      redirect_to staff_order_path(@order), alert: "The order could not be cancelled and refunded. Please try again or contact an administrator."
    end

    private

    def set_order
      @order = current_restaurant.orders.includes(:user, :checkout_group, order_items: :menu_item).find(params[:id])
    end

    def order_params
      params.require(:order).permit(
        :customer_name,
        order_items_attributes: %i[menu_item_id quantity]
      )
    end

    def build_order_items(attributes)
      seen_menu_item_ids = []
      attributes&.each_value do |attributes_for_item|
        quantity = attributes_for_item[:quantity]
        next if quantity.blank? || quantity.to_s == "0"

        menu_item_id = attributes_for_item[:menu_item_id]
        if seen_menu_item_ids.include?(menu_item_id.to_s)
          @order.errors.add(:base, "A menu item can only be selected once.")
          next
        end
        seen_menu_item_ids << menu_item_id.to_s

        menu_item = current_restaurant.menu_items.available.find_by(id: menu_item_id)
        unless menu_item
          @order.errors.add(:base, "A selected menu item is no longer available.")
          next
        end

        @order.order_items.build(menu_item: menu_item, quantity: quantity, unit_price: menu_item.price)
      end
    end

    def load_available_menu_items
      @menu_items = current_restaurant.menu_items.available.order(:name)
    end
  end
end
