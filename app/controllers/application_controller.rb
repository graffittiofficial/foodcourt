class ApplicationController < ActionController::Base
  include Authentication
  include ErrorHandling

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def valid_request_origin?
    return true if Rails.env.development? && request.origin == "https://localhost:3000"

    super
  end
end
