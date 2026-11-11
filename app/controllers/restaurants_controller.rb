class RestaurantsController < ApplicationController
  allow_unauthenticated_access

  def index
    @query = params[:q].to_s.strip
    @restaurants = Restaurant.includes(:reviews, :photo_attachment, menu_items: [ :photo_attachment ]).order(:name)
    @restaurants = Search::Filter.restaurants(@restaurants, @query)
  end

  def show
    @restaurant = Restaurant.includes(:reviews, :photo_attachment, menu_items: [ :reviews, :photo_attachment ]).find(params[:id])
    @menu_items = @restaurant.menu_items.available.includes(:reviews, :photo_attachment).order(:name)
  end
end
