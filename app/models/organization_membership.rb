class OrganizationMembership < ApplicationRecord
  belongs_to :organization
  belongs_to :user

  validates :user_id, uniqueness: { scope: :organization_id }
  validate :user_must_not_be_a_driver

  before_destroy :keep_one_active_admin

  private

  def user_must_not_be_a_driver
    errors.add(:user, "cannot be an Organization admin while assigned as a Driver") if user&.driver?
  end

  def keep_one_active_admin
    organization.with_lock do
      return if organization.organization_memberships.where.not(id: id).exists?

      errors.add(:base, "An Organization must have at least one active admin.")
      throw :abort
    end
  end
end
