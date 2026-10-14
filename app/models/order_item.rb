class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :menu_item

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :menu_item_name, presence: true

  before_validation :snapshot_menu_item, on: :create
  validate :menu_item_belongs_to_order_restaurant

  private

  def snapshot_menu_item
    return unless menu_item

    self.unit_price = menu_item.price if unit_price.nil?
    self.menu_item_name ||= menu_item.name
  end

  def menu_item_belongs_to_order_restaurant
    return unless order && menu_item
    return if order.restaurant_id == menu_item.restaurant_id

    errors.add(:menu_item, "must belong to the order's restaurant")
  end
end
