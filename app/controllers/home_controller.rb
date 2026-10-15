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
      @query = params[:q].to_s.strip
      @restaurants = Restaurant.includes(:reviews, :photo_attachment, menu_items: [ :photo_attachment ]).order(:name)
      @restaurants = @restaurants.where("restaurants.name ILIKE ?", "%#{Restaurant.sanitize_sql_like(@query)}%") if @query.present?
    end
  end
end
