class Order < ApplicationRecord
  STATUSES = {
    pending: "pending",
    preparing: "preparing",
    ready: "ready",
    completed: "completed",
    cancelled: "cancelled"
  }.freeze

  STATUS_TRANSITIONS = {
    "pending" => "preparing",
    "preparing" => "ready",
    "ready" => "completed"
  }.freeze

  belongs_to :restaurant
  belongs_to :user, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :driver, class_name: "User", optional: true
  belongs_to :checkout_group, optional: true
  has_many :order_items, dependent: :destroy
  has_many :reviews, dependent: :destroy

  enum :status, STATUSES, default: :pending, validate: true
  enum :delivery_status, {
    unassigned: "unassigned",
    assigned: "assigned",
    picked_up: "picked_up",
    delivered: "delivered"
  }, default: :unassigned, validate: true

  validates :customer_name, presence: true
  validates_associated :order_items
  validate :created_by_is_staff_for_restaurant
  validate :assigned_driver_must_be_driver
  validate :status_transition_is_allowed, if: :will_save_change_to_status?
  validate :delivery_transition_is_allowed, if: :will_save_change_to_delivery_status?

  def total
    order_items.sum("unit_price * quantity") + (checkout_group&.delivery_fee || 0)
  end

  def advance_status
    next_status = STATUS_TRANSITIONS[status]
    unless next_status
      errors.add(:status, "cannot be advanced from #{status}")
      return false
    end

    update(status: next_status)
  end

  def cancel
    unless pending? || preparing? || ready?
      errors.add(:status, "cannot be cancelled from #{status}")
      return false
    end

    update(status: :cancelled)
  end

  def update_delivery_status(next_status)
    allowed_next_status = {
      "unassigned" => "assigned",
      "assigned" => "picked_up",
      "picked_up" => "delivered"
    }[delivery_status]
    unless allowed_next_status == next_status.to_s
      errors.add(:delivery_status, "cannot transition from #{delivery_status} to #{next_status}")
      return false
    end

    update(delivery_status: next_status)
  end

  private

  def assigned_driver_must_be_driver
    return unless driver
    return if driver.driver?

    errors.add(:driver, "must have the driver role")
  end

  def created_by_is_staff_for_restaurant
    return unless created_by
    return if created_by.staff? && created_by.restaurant_id == restaurant_id

    errors.add(:created_by, "must be staff for this restaurant")
  end

  def status_transition_is_allowed
    return unless persisted?

    previous_status = status_in_database
    next_status = status
    allowed = STATUS_TRANSITIONS[previous_status] == next_status ||
      (next_status == "cancelled" && %w[pending preparing ready].include?(previous_status))
    return if allowed

    errors.add(:status, "cannot transition from #{previous_status} to #{next_status}")
  end

  def delivery_transition_is_allowed
    return unless persisted?

    previous_status = delivery_status_in_database
    next_status = delivery_status
    allowed = {
      "unassigned" => "assigned",
      "assigned" => %w[picked_up unassigned],
      "picked_up" => "delivered"
    }[previous_status]
    return if allowed == next_status || allowed.is_a?(Array) && allowed.include?(next_status)

    errors.add(:delivery_status, "cannot transition from #{previous_status} to #{next_status}")
  end
end
