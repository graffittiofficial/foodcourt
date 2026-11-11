class RestaurantMembership < ApplicationRecord
  belongs_to :restaurant
  belongs_to :user

  validates :restaurant_id, uniqueness: { scope: :user_id }
  validate :user_must_not_be_a_driver
  validate :user_must_belong_to_only_one_organization

  private

  def user_must_not_be_a_driver
    errors.add(:user, "cannot be Restaurant staff while assigned as a Driver") if user&.driver?
  end

  def user_must_belong_to_only_one_organization
    return unless user && restaurant
    return unless user.restaurant_memberships.joins(:restaurant)
      .where.not(restaurant_id: restaurant_id)
      .where.not(restaurants: { organization_id: restaurant.organization_id })
      .exists?

    errors.add(:user, "cannot be staff across multiple Organizations")
  end
end
