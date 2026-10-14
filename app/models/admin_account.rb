class AdminAccount < ApplicationRecord
  self.table_name = "admins"

  has_secure_password
  has_many :sessions, foreign_key: :admin_id, dependent: :destroy

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, uniqueness: true

  def admin?
    true
  end

  def staff?
    false
  end
end
