class RestaurantsController < ApplicationController
  allow_unauthenticated_access

  def index
    @restaurants = Restaurant.includes(:menu_items).order(:name)
  end

  def show
    @restaurant = Restaurant.find(params[:id])
    @menu_items = @restaurant.menu_items.available.order(:name)
  end
end
