class Cart < ApplicationRecord
  belongs_to :user
  has_many :cart_items, dependent: :destroy

  validates :user_id, uniqueness: true

  def add_item(menu_item, quantity)
    item = cart_items.find_or_initialize_by(menu_item: menu_item)
    item.quantity = item.quantity.to_i + quantity.to_i
    item.save!
    item
  end

  def total
    cart_items.joins(:menu_item).sum("menu_items.price * cart_items.quantity")
  end
end
