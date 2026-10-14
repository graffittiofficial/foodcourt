class StripeWebhooksController < ApplicationController
  skip_before_action :require_authentication
  skip_forgery_protection

  def create
    secret = ENV["STRIPE_WEBHOOK_SECRET"]
    if secret.blank?
      Rails.logger.error("Stripe webhook signing secret is not configured.")
      return head :service_unavailable
    end

    event = Stripe::Webhook.construct_event(
      request.raw_post,
      request.headers["Stripe-Signature"],
      secret
    )

    case event.type
    when "checkout.session.completed"
      checkout = Checkout.find_by!(stripe_checkout_session_id: event.data.object.id)
      FulfillCheckout.new(checkout: checkout, stripe_session: event.data.object).call
    when "checkout.session.expired"
      checkout = Checkout.find_by!(stripe_checkout_session_id: event.data.object.id)
      checkout.expired! if checkout.pending?
    end

    head :ok
  rescue Stripe::SignatureVerificationError, JSON::ParserError => error
    Rails.logger.warn("Rejected Stripe webhook: #{error.message}")
    head :bad_request
  rescue ActiveRecord::RecordNotFound => error
    Rails.logger.error("Stripe webhook references an unknown checkout: #{error.message}")
    head :unprocessable_entity
  rescue FulfillCheckout::Error, Stripe::StripeError, StripeGateway::Error => error
    Rails.logger.error("Stripe webhook processing failed: #{error.class}: #{error.message}")
    head :internal_server_error
  end
end
