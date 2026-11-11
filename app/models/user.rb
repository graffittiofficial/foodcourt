class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :restaurant_memberships, dependent: :destroy
  has_many :restaurants, through: :restaurant_memberships
  has_many :organization_memberships, dependent: :destroy
  has_many :administered_organizations, through: :organization_memberships, source: :organization
  has_one :cart, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error
  has_many :reviews, dependent: :destroy
  has_many :created_orders, class_name: "Order", foreign_key: :created_by_id, dependent: :nullify
  has_many :assigned_orders, class_name: "Order", foreign_key: :driver_id, dependent: :nullify
  has_many :checkouts, dependent: :restrict_with_error

  enum :role, { customer: "customer", staff: "staff", driver: "driver" }, default: :customer, validate: true

  validates :name, presence: true, if: :driver?
  validate :drivers_cannot_have_management_memberships

  def staff?
    restaurant_memberships.exists?
  end

  def organization_admin?
    organization_memberships.exists?
  end

  def staff_for?(restaurant)
    restaurant_memberships.exists?(restaurant_id: restaurant.id)
  end

  def organization_admin_for?(organization)
    organization_memberships.exists?(organization_id: organization.id)
  end

  def organizations_for_management
    Organization.where(id: organization_memberships.select(:organization_id))
      .or(Organization.where(id: Restaurant.joins(:restaurant_memberships)
        .where(restaurant_memberships: { user_id: id })
        .select(:organization_id)))
  end

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  private

  def drivers_cannot_have_management_memberships
    return unless driver? && (restaurant_memberships.any? || organization_memberships.any?)

    errors.add(:role, "Drivers cannot have Organization or Restaurant management access")
  end
end
