class HomeController < ApplicationController
  allow_unauthenticated_access

  def show
    if Current.account&.admin?
      redirect_to admin_root_path
    elsif Current.account&.staff?
      redirect_to staff_dashboard_path
    elsif Current.account&.driver?
      redirect_to driver_root_path
    else
      @restaurants = Restaurant.includes(:menu_items).order(:name)
    end
  end
end
