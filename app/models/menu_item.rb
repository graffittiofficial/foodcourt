class MenuItem < ApplicationRecord
  belongs_to :restaurant
  has_many :cart_items, dependent: :restrict_with_error
  has_many :order_items, dependent: :restrict_with_error
  has_many :reviews, as: :reviewable, dependent: :destroy
  has_one_attached :photo

  scope :active, -> { where(archived_at: nil) }
  scope :available, -> { active.where(available: true) }

  validates :name, presence: true,
    uniqueness: { scope: :restaurant_id, conditions: -> { where(archived_at: nil) } },
    if: -> { archived_at.nil? }
  validates :price, numericality: { greater_than: 0 }
  validate :photo_is_valid

  def rating_average
    ratings = reviews.map(&:rating)
    return if ratings.empty?

    (ratings.sum.to_f / ratings.length).round(1)
  end

  def rating_count
    reviews.size
  end

  private

  def photo_is_valid
    return unless photo.attached?

    errors.add(:photo, "must be a JPEG, PNG, or WebP image") unless photo.blob.content_type.in?(%w[image/jpeg image/png image/webp])
    errors.add(:photo, "must be smaller than 5 MB") if photo.blob.byte_size > 5.megabytes
  end
end
