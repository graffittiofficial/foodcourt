class AddMarketplaceCheckoutAndDelivery < ActiveRecord::Migration[8.1]
  def change
    remove_reference :carts, :restaurant, foreign_key: true

    remove_check_constraint :users, name: "users_role_check"
    add_check_constraint :users, "role IN ('customer', 'staff', 'driver')", name: "users_role_check"
    add_column :users, :name, :string

    add_column :restaurants, :address_line1, :string
    add_column :restaurants, :city, :string
    add_column :restaurants, :region, :string
    add_column :restaurants, :postal_code, :string
    add_column :restaurants, :country_code, :string
    add_column :restaurants, :google_place_id, :string
    add_column :restaurants, :stripe_account_id, :string
    add_column :restaurants, :stripe_account_onboarded_at, :datetime
    add_column :restaurants, :delivery_base_fee, :decimal, precision: 10, scale: 2
    add_column :restaurants, :delivery_fee_per_km, :decimal, precision: 10, scale: 2
    add_column :restaurants, :max_delivery_distance_km, :decimal, precision: 8, scale: 2
    add_index :restaurants, :stripe_account_id, unique: true
    add_check_constraint :restaurants, "delivery_base_fee IS NULL OR delivery_base_fee >= 0", name: "restaurants_delivery_base_fee_nonnegative"
    add_check_constraint :restaurants, "delivery_fee_per_km IS NULL OR delivery_fee_per_km >= 0", name: "restaurants_delivery_fee_per_km_nonnegative"
    add_check_constraint :restaurants, "max_delivery_distance_km IS NULL OR max_delivery_distance_km > 0", name: "restaurants_delivery_radius_positive"

    create_table :checkouts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :stripe_checkout_session_id
      t.string :stripe_payment_intent_id
      t.string :customer_name, null: false
      t.string :customer_phone, null: false
      t.string :address_line1, null: false
      t.string :address_line2
      t.string :city, null: false
      t.string :region, null: false
      t.string :postal_code, null: false
      t.string :country_code, null: false
      t.string :google_place_id
      t.bigint :total_amount_cents, null: false
      t.string :currency, null: false, default: "usd"
      t.datetime :paid_at
      t.timestamps
    end
    add_index :checkouts, :stripe_checkout_session_id, unique: true
    add_index :checkouts, :stripe_payment_intent_id
    add_check_constraint :checkouts, "total_amount_cents > 0", name: "checkouts_total_positive"
    add_check_constraint :checkouts, "status IN ('pending', 'paid', 'expired')", name: "checkouts_status_valid"

    create_table :checkout_groups do |t|
      t.references :checkout, null: false, foreign_key: true
      t.references :restaurant, null: false, foreign_key: true
      t.references :order, foreign_key: true, index: false
      t.decimal :distance_km, precision: 8, scale: 3, null: false
      t.decimal :delivery_fee, precision: 10, scale: 2, null: false
      t.string :stripe_transfer_id
      t.string :stripe_transfer_reversal_id
      t.string :stripe_refund_id
      t.timestamps
    end
    add_index :checkout_groups, [ :checkout_id, :restaurant_id ], unique: true
    add_index :checkout_groups, :order_id, unique: true
    add_index :checkout_groups, :stripe_transfer_id, unique: true
    add_check_constraint :checkout_groups, "distance_km >= 0", name: "checkout_groups_distance_nonnegative"
    add_check_constraint :checkout_groups, "delivery_fee >= 0", name: "checkout_groups_delivery_fee_nonnegative"

    create_table :checkout_items do |t|
      t.references :checkout_group, null: false, foreign_key: true
      t.references :menu_item, foreign_key: true
      t.string :menu_item_name, null: false
      t.integer :quantity, null: false
      t.decimal :unit_price, precision: 10, scale: 2, null: false
      t.timestamps
    end
    add_index :checkout_items, [ :checkout_group_id, :menu_item_id ], unique: true
    add_check_constraint :checkout_items, "quantity > 0", name: "checkout_items_quantity_positive"
    add_check_constraint :checkout_items, "unit_price >= 0", name: "checkout_items_unit_price_nonnegative"

    add_reference :orders, :checkout_group, foreign_key: true, index: false
    add_reference :orders, :driver, foreign_key: { to_table: :users }
    add_column :orders, :delivery_status, :string, null: false, default: "unassigned"
    add_column :orders, :refunded_at, :datetime
    add_index :orders, :checkout_group_id, unique: true
    add_index :orders, [ :driver_id, :delivery_status ]
    add_check_constraint :orders,
      "delivery_status IN ('unassigned', 'assigned', 'picked_up', 'delivered')",
      name: "orders_delivery_status_valid"
  end
end
