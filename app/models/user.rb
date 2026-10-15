class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  belongs_to :restaurant, optional: true
  has_one :cart, dependent: :destroy
  has_many :orders, dependent: :restrict_with_error
  has_many :reviews, dependent: :destroy
  has_many :created_orders, class_name: "Order", foreign_key: :created_by_id, dependent: :nullify
  has_many :assigned_orders, class_name: "Order", foreign_key: :driver_id, dependent: :nullify
  has_many :checkouts, dependent: :restrict_with_error

  enum :role, { customer: "customer", staff: "staff", driver: "driver" }, default: :customer, validate: true

  validates :restaurant, presence: true, if: :staff?
  validates :restaurant, absence: true, if: -> { customer? || driver? }
  validates :name, presence: true, if: :driver?

  normalizes :email_address, with: ->(e) { e.strip.downcase }
end
