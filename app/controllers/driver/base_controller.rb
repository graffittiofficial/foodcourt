module Driver
  class BaseController < ApplicationController
    before_action :require_driver

    private

    def require_driver
      return if Current.account.is_a?(User) && Current.account.driver?

      head :forbidden
    end
  end
end
