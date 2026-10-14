class RefundOrder
  class Error < StandardError; end

  def initialize(order:, stripe: StripeGateway.new)
    @order = order
    @stripe = stripe
  end

  def call
    raise Error, "Only paid customer orders can be refunded." unless @order.checkout_group&.checkout&.paid?
    raise Error, "Only pending, preparing, or ready orders can be cancelled." unless @order.pending? || @order.preparing? || @order.ready?

    @stripe.refund_order!(@order)
    @order.update!(refunded_at: Time.current) if @order.refunded_at.nil?
    raise Error, @order.errors.full_messages.to_sentence unless @order.cancel

    true
  end
end
