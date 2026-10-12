module ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ActionController::RoutingError, with: :render_not_found
    rescue_from ActionController::ParameterMissing, with: :render_unprocessable_entity
  end

  private

  def render_not_found(exception = nil)
    Rails.logger.warn("Resource not found: #{exception.message}") if exception
    render "errors/not_found", status: :not_found
  end

  def render_unprocessable_entity(exception = nil)
    Rails.logger.warn("Invalid request: #{exception.message}") if exception
    render "errors/unprocessable_entity", status: :unprocessable_entity
  end

  def render_internal_server_error(exception = nil)
    Rails.logger.error("Internal server error: #{exception.message}") if exception
    render "errors/internal_server_error", status: :internal_server_error
  end
end
