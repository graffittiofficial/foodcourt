class Checkout < ApplicationRecord
  belongs_to :user
  has_many :checkout_groups, dependent: :destroy
  has_many :checkout_items, through: :checkout_groups

  enum :status, { pending: "pending", paid: "paid", expired: "expired" }, default: :pending, validate: true

  validates :total_amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :address_line1, :city, :region, :postal_code, :country_code, presence: true

  def mark_paid!(payment_intent_id:, charge_id:)
    with_lock do
      return if paid? && stripe_charge_id.present?

      update!(
        status: :paid,
        stripe_payment_intent_id: payment_intent_id,
        stripe_charge_id: charge_id,
        paid_at: Time.current
      )
    end
  end

  def total_amount
    BigDecimal(total_amount_cents.to_s) / 100
  end
end
