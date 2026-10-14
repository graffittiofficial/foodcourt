class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :menu_item

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :menu_item_id, uniqueness: { scope: :cart_id }
  validate :menu_item_is_available_in_cart_restaurant

  private

  def menu_item_is_available_in_cart_restaurant
    return unless cart && menu_item

    if menu_item.archived_at.present? || !menu_item.available?
      errors.add(:menu_item, "is not available")
    end
  end
end
