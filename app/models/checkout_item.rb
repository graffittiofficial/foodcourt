class CheckoutItem < ApplicationRecord
  belongs_to :checkout_group
  belongs_to :menu_item, optional: true

  validates :menu_item_name, presence: true
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
end
