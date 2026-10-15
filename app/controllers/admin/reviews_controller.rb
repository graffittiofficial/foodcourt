module Admin
  class ReviewsController < BaseController
    def index
      @reviews = Review.includes(:user, :order, :reviewable).order(created_at: :desc).limit(100)
    end

    def destroy
      review = Review.find(params[:id])
      review.destroy!
      redirect_to admin_reviews_path, notice: "Review removed."
    end
  end
end
