module OrganizationAdmin
  class ReviewsController < BaseController
    def index
      @query = params[:q].to_s.strip
      scoped_reviews = Review.where(order_id: Order.where(restaurant_id: current_organization.restaurants.select(:id)))
        .includes(:user, :order, :reviewable)
        .order(created_at: :desc, id: :desc)
      @reviews = Search::Filter.reviews(scoped_reviews, @query).limit(100)
    end
  end
end
