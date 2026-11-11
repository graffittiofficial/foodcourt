class InvitationRestaurant < ApplicationRecord
  belongs_to :invitation
  belongs_to :restaurant

  validates :restaurant_id, uniqueness: { scope: :invitation_id }
  validate :restaurant_must_belong_to_invitation_organization

  private

  def restaurant_must_belong_to_invitation_organization
    return if invitation && restaurant && invitation.organization_id == restaurant.organization_id

    errors.add(:restaurant, "must belong to the invited Organization")
  end
end
