module Admin
  class BaseController < ApplicationController
    layout "admin"

    before_action :require_admin

    private

    def require_admin
      return if Current.account&.admin?

      redirect_to new_session_path, alert: "Admin access is required."
    end
  end
end
