class MenuItem < ApplicationRecord
  belongs_to :restaurant
  has_many :cart_items, dependent: :restrict_with_error
  has_many :order_items, dependent: :restrict_with_error

  scope :active, -> { where(archived_at: nil) }
  scope :available, -> { active.where(available: true) }

  validates :name, presence: true,
    uniqueness: { scope: :restaurant_id, conditions: -> { where(archived_at: nil) } },
    if: -> { archived_at.nil? }
  validates :price, numericality: { greater_than: 0 }
end
