class ReviewsController < ApplicationController
  before_action :require_customer
  before_action :set_review, only: %i[update destroy]

  def create
    order = Current.account.orders.find(params[:order_id])
    reviewable = reviewable_for(order)
    @review = order.reviews.find_or_initialize_by(reviewable: reviewable)
    @review.user = Current.account

    if @review.update(review_params.slice(:rating, :body))
      redirect_to order_path(order), notice: "Your rating has been published."
    else
      redirect_to order_path(order), alert: @review.errors.full_messages.to_sentence
    end
  end

  def update
    if @review.update(review_params.slice(:rating, :body))
      redirect_to order_path(@review.order), notice: "Your rating has been updated."
    else
      redirect_to order_path(@review.order), alert: @review.errors.full_messages.to_sentence
    end
  end

  def destroy
    order = @review.order
    @review.destroy!
    redirect_to order_path(order), notice: "Your rating has been deleted."
  end

  private

  def require_customer
    return if Current.account.is_a?(User) && Current.account.customer?

    redirect_to root_path, alert: "Customer access is required."
  end

  def set_review
    @review = Current.account.reviews.find(params[:id])
  end

  def reviewable_for(order)
    case params.require(:review).fetch(:reviewable_type)
    when "Restaurant"
      order.restaurant
    when "MenuItem"
      order.order_items.includes(:menu_item).find_by!(menu_item_id: params.require(:review).fetch(:menu_item_id)).menu_item
    else
      raise ActionController::BadRequest, "Choose a restaurant or ordered menu item to review."
    end
  end

  def review_params
    params.require(:review).permit(:rating, :body, :reviewable_type, :menu_item_id)
  end
end
