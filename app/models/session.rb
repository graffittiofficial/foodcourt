class Session < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :admin, class_name: "AdminAccount", optional: true

  validate :belongs_to_exactly_one_account

  def account
    admin || user
  end

  private

  def belongs_to_exactly_one_account
    return if [ user_id, admin_id ].compact.one?

    errors.add(:base, "must belong to exactly one account")
  end
end
