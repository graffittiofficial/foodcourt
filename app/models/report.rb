class Report < ApplicationRecord
  CATEGORIES = {
    finance: "finance",
    operations: "operations",
    kitchen_product: "kitchen_product"
  }.freeze

  STATUSES = {
    queued: "queued",
    processing: "processing",
    completed: "completed",
    failed: "failed",
    expired: "expired"
  }.freeze

  belongs_to :requester, class_name: "User"
  belongs_to :organization
  belongs_to :restaurant, optional: true
  belongs_to :report_schedule, optional: true
  has_many :report_deliveries, dependent: :destroy
  has_one_attached :file

  enum :category, CATEGORIES, validate: true
  enum :status, STATUSES, default: :queued, validate: true

  validates :start_date, :end_date, presence: true
  validate :date_range_is_valid
  validate :restaurant_belongs_to_organization

  scope :newest_first, -> { order(created_at: :desc) }

  def accessible_by?(user)
    Reports::Access.can_access_scope?(user, organization: organization, restaurant: restaurant)
  end

  def generate_csv
    Reports::CsvBuilder.new(self).call
  end

  def filename
    "#{category}_#{start_date.iso8601}_to_#{end_date.iso8601}.csv"
  end

  def downloadable?
    completed? && expires_at&.future? && file.attached?
  end

  def email_recipients
    report_deliveries.includes(:user).filter_map do |delivery|
      delivery.user if accessible_by?(delivery.user)
    end
  end

  private

  def date_range_is_valid
    return unless start_date && end_date

    errors.add(:end_date, "must be on or after the start date") if end_date < start_date
    errors.add(:end_date, "must be within one year of the start date") if end_date > start_date + 1.year
  end

  def restaurant_belongs_to_organization
    return unless restaurant && organization_id != restaurant.organization_id

    errors.add(:restaurant, "must belong to the selected Organization")
  end
end
