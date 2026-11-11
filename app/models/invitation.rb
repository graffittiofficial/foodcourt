class Invitation < ApplicationRecord
  ROLES = { organization_admin: "organization_admin", staff: "staff" }.freeze

  belongs_to :organization
  belongs_to :invited_by_user, class_name: "User", optional: true
  belongs_to :invited_by_admin, class_name: "AdminAccount", optional: true
  has_many :invitation_restaurants, dependent: :destroy
  has_many :restaurants, through: :invitation_restaurants

  enum :role, ROLES, validate: true

  attr_accessor :token

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  before_validation :prepare_token, on: :create

  validates :email_address, presence: true
  validates :token_digest, presence: true, uniqueness: true
  validate :has_exactly_one_inviter
  validate :restaurants_match_role_and_organization
  validate :invitee_is_not_a_driver

  scope :outstanding, -> { where(accepted_at: nil, revoked_at: nil) }
  scope :pending, -> { outstanding.where("expires_at > ?", Time.current) }

  def active?
    accepted_at.nil? && revoked_at.nil? && expires_at&.future?
  end

  def accept!(user: nil, name: nil, password: nil, password_confirmation: nil)
    raise ActiveRecord::RecordNotFound unless active?

    user ||= User.new(
      name: name,
      email_address: email_address,
      password: password,
      password_confirmation: password_confirmation,
      role: :customer
    )

    raise ActiveRecord::RecordNotFound unless user.email_address == email_address
    raise ActiveRecord::RecordInvalid, user if user.driver?

    Invitation.transaction do
      user.save! unless user.persisted?
      if organization_admin?
        OrganizationMembership.find_or_create_by!(organization: organization, user: user)
      else
        restaurants.each do |restaurant|
          RestaurantMembership.find_or_create_by!(restaurant: restaurant, user: user)
        end
      end
      update!(accepted_at: Time.current)
    end

    user
  end

  def revoke!
    return false if accepted_at || revoked_at

    update!(revoked_at: Time.current)
  end

  def resend!
    return false if accepted_at || revoked_at

    self.token = SecureRandom.urlsafe_base64(32)
    update!(token_digest: Digest::SHA256.hexdigest(token), expires_at: 7.days.from_now)
    InvitationsMailer.invite(self, token).deliver_later
  end

  private

  def prepare_token
    return if token.present?

    self.token = SecureRandom.urlsafe_base64(32)
    self.token_digest = Digest::SHA256.hexdigest(token)
    self.expires_at = 7.days.from_now
  end

  def has_exactly_one_inviter
    return if [ invited_by_user_id, invited_by_admin_id ].compact.one?

    errors.add(:base, "An invitation must have exactly one inviter")
  end

  def restaurants_match_role_and_organization
    return if organization_admin? && invitation_restaurants.empty?
    return if staff? && invitation_restaurants.any? &&
      invitation_restaurants.all? { |assignment| assignment.restaurant&.organization_id == organization_id }

    errors.add(:restaurants, "must be assigned to a staff invitation within its Organization")
  end

  def invitee_is_not_a_driver
    return if email_address.blank?
    if AdminAccount.exists?(email_address: email_address)
      errors.add(:email_address, "belongs to a platform admin account")
      return
    end
    return unless User.find_by(email_address: email_address)&.driver?

    errors.add(:email_address, "belongs to a Driver account that cannot receive management access")
  end
end
