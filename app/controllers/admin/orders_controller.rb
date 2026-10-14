module Admin
  class OrdersController < BaseController
    def index
      @orders = Order.includes(:restaurant, :user, :driver, checkout_group: :checkout)
        .where.not(checkout_group_id: nil)
        .where(delivery_status: %i[unassigned assigned])
        .order(created_at: :desc)
      @drivers = User.driver.order(:name, :email_address)
    end

    def update
      @order = Order.find(params[:id])
      driver_id = params.require(:order).permit(:driver_id)[:driver_id]
      raise ActiveRecord::RecordNotFound unless @order.checkout_group
      unless @order.unassigned? || @order.assigned?
        @order.errors.add(:delivery_status, "can only be assigned before pickup")
        raise ActiveRecord::RecordInvalid, @order
      end

      if driver_id.blank?
        @order.update!(driver: nil, delivery_status: :unassigned)
      else
        driver = User.driver.find(driver_id)
        @order.update!(driver: driver, delivery_status: :assigned)
      end

      redirect_to admin_orders_path, notice: "Delivery assignment updated."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to admin_orders_path, alert: error.record.errors.full_messages.to_sentence
    end
  end
end
