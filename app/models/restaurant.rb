class Restaurant < ApplicationRecord
  has_many :users, dependent: :restrict_with_error
  has_many :menu_items, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error
  has_many :checkout_groups, dependent: :restrict_with_error
  has_many :reviews, as: :reviewable, dependent: :destroy
  has_one_attached :photo

  validates :name, presence: true
  validates :delivery_base_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :delivery_fee_per_km, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_delivery_distance_km, numericality: { greater_than: 0 }, allow_nil: true
  validate :delivery_settings_are_complete
  validate :photo_is_valid

  def rating_average
    ratings = reviews.map(&:rating)
    return if ratings.empty?

    (ratings.sum.to_f / ratings.length).round(1)
  end

  def rating_count
    reviews.size
  end

  def delivery_configured?
    [ address_line1, city, region, postal_code, country_code, google_place_id,
      delivery_base_fee, delivery_fee_per_km, max_delivery_distance_km ].all?(&:present?)
  end

  def stripe_connected?
    stripe_account_id.present? && stripe_account_onboarded_at.present?
  end

  def delivery_fee_for(distance_km)
    raise ArgumentError, "Delivery is not configured for this restaurant" unless delivery_configured?
    raise ArgumentError, "Delivery is outside this restaurant's range" if distance_km > max_delivery_distance_km

    (delivery_base_fee + delivery_fee_per_km * distance_km).round(2)
  end

  private

  def delivery_settings_are_complete
    delivery_fields = %i[
      address_line1 city region postal_code country_code google_place_id
      delivery_base_fee delivery_fee_per_km max_delivery_distance_km
    ]
    return unless delivery_fields.any? { |field| public_send(field).present? }
    return if delivery_fields.all? { |field| public_send(field).present? }

    errors.add(:base, "Delivery address, fees, radius, and Google Place ID must all be configured together.")
  end

  def photo_is_valid
    return unless photo.attached?

    errors.add(:photo, "must be a JPEG, PNG, or WebP image") unless photo.blob.content_type.in?(%w[image/jpeg image/png image/webp])
    errors.add(:photo, "must be smaller than 5 MB") if photo.blob.byte_size > 5.megabytes
  end
end
