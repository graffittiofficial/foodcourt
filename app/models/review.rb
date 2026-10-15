class Review < ApplicationRecord
  belongs_to :user
  belongs_to :order
  belongs_to :reviewable, polymorphic: true

  validates :rating, numericality: { only_integer: true, in: 1..5 }
  validates :body, length: { maximum: 1_000 }, allow_nil: true
  validates :reviewable_id, uniqueness: { scope: %i[order_id reviewable_type] }
  validate :customer_owns_delivered_order
  validate :reviewable_was_ordered

  private

  def customer_owns_delivered_order
    return unless order
    return if order.user_id == user_id && order.delivery_status == "delivered"

    errors.add(:order, "must be a delivery completed by this customer")
  end

  def reviewable_was_ordered
    return unless order && reviewable

    valid_reviewable = case reviewable
    when Restaurant
      order.restaurant_id == reviewable.id
    when MenuItem
      order.restaurant_id == reviewable.restaurant_id &&
        order.order_items.exists?(menu_item_id: reviewable.id)
    else
      false
    end
    return if valid_reviewable

    errors.add(:reviewable, "must be a restaurant or menu item from this order")
  end
end
