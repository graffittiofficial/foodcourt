class CheckoutGroup < ApplicationRecord
  belongs_to :checkout
  belongs_to :restaurant
  has_one :order, dependent: :restrict_with_error
  has_many :checkout_items, dependent: :destroy

  validates :distance_km, numericality: { greater_than_or_equal_to: 0 }
  validates :delivery_fee, numericality: { greater_than_or_equal_to: 0 }

  def subtotal
    checkout_items.sum("unit_price * quantity")
  end

  def total
    subtotal + delivery_fee
  end

  def total_amount_cents
    (total * 100).round
  end
end
