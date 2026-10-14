module Staff
  class BaseController < ApplicationController
    before_action :require_staff

    private

    def require_staff
      return if Current.user&.staff? && Current.user.restaurant.present?

      head :forbidden
    end

    def current_restaurant
      Current.user.restaurant
    end
  end
end
