require "test_helper"

class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
  test "webhook requests are unavailable without a signing secret" do
    with_webhook_secret(nil) do
      post stripe_webhook_path, params: "{}", headers: { "CONTENT_TYPE" => "application/json" }
    end

    assert_response :service_unavailable
  end

  test "webhook requests with an invalid signature are rejected" do
    with_webhook_secret("whsec_test") do
      post stripe_webhook_path,
        params: "{}",
        headers: {
          "CONTENT_TYPE" => "application/json",
          "Stripe-Signature" => "t=0,v1=invalid"
        }
    end

    assert_response :bad_request
  end

  private

  def with_webhook_secret(secret)
    previous_secret = ENV["STRIPE_WEBHOOK_SECRET"]
    secret.nil? ? ENV.delete("STRIPE_WEBHOOK_SECRET") : ENV["STRIPE_WEBHOOK_SECRET"] = secret
    yield
  ensure
    previous_secret.nil? ? ENV.delete("STRIPE_WEBHOOK_SECRET") : ENV["STRIPE_WEBHOOK_SECRET"] = previous_secret
  end
end
