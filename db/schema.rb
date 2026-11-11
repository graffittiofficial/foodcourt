# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_10_090000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_admins_on_email_address", unique: true
  end

  create_table "cart_items", force: :cascade do |t|
    t.bigint "cart_id", null: false
    t.bigint "menu_item_id", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cart_id", "menu_item_id"], name: "index_cart_items_on_cart_id_and_menu_item_id", unique: true
    t.index ["cart_id"], name: "index_cart_items_on_cart_id"
    t.index ["menu_item_id"], name: "index_cart_items_on_menu_item_id"
  end

  create_table "carts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_carts_on_user_id", unique: true
  end

  create_table "checkout_groups", force: :cascade do |t|
    t.bigint "checkout_id", null: false
    t.bigint "restaurant_id", null: false
    t.decimal "distance_km", precision: 8, scale: 3, null: false
    t.decimal "delivery_fee", precision: 10, scale: 2, null: false
    t.string "stripe_transfer_id"
    t.string "stripe_transfer_reversal_id"
    t.string "stripe_refund_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checkout_id", "restaurant_id"], name: "index_checkout_groups_on_checkout_id_and_restaurant_id", unique: true
    t.index ["checkout_id"], name: "index_checkout_groups_on_checkout_id"
    t.index ["restaurant_id"], name: "index_checkout_groups_on_restaurant_id"
    t.index ["stripe_transfer_id"], name: "index_checkout_groups_on_stripe_transfer_id", unique: true
    t.check_constraint "delivery_fee >= 0::numeric", name: "checkout_groups_delivery_fee_nonnegative"
    t.check_constraint "distance_km >= 0::numeric", name: "checkout_groups_distance_nonnegative"
  end

  create_table "checkout_items", force: :cascade do |t|
    t.bigint "checkout_group_id", null: false
    t.bigint "menu_item_id"
    t.string "menu_item_name", null: false
    t.integer "quantity", null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checkout_group_id", "menu_item_id"], name: "index_checkout_items_on_checkout_group_id_and_menu_item_id", unique: true
    t.index ["checkout_group_id"], name: "index_checkout_items_on_checkout_group_id"
    t.index ["menu_item_id"], name: "index_checkout_items_on_menu_item_id"
    t.check_constraint "quantity > 0", name: "checkout_items_quantity_positive"
    t.check_constraint "unit_price >= 0::numeric", name: "checkout_items_unit_price_nonnegative"
  end

  create_table "checkouts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "status", default: "pending", null: false
    t.string "stripe_checkout_session_id"
    t.string "stripe_payment_intent_id"
    t.string "customer_name", null: false
    t.string "customer_phone", null: false
    t.string "address_line1", null: false
    t.string "address_line2"
    t.string "city", null: false
    t.string "region", null: false
    t.string "postal_code", null: false
    t.string "country_code", null: false
    t.string "google_place_id"
    t.bigint "total_amount_cents", null: false
    t.string "currency", default: "usd", null: false
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_charge_id"
    t.index ["stripe_charge_id"], name: "index_checkouts_on_stripe_charge_id"
    t.index ["stripe_checkout_session_id"], name: "index_checkouts_on_stripe_checkout_session_id", unique: true
    t.index ["stripe_payment_intent_id"], name: "index_checkouts_on_stripe_payment_intent_id"
    t.index ["user_id"], name: "index_checkouts_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'paid'::character varying::text, 'expired'::character varying::text])", name: "checkouts_status_valid"
    t.check_constraint "total_amount_cents > 0", name: "checkouts_total_positive"
  end

  create_table "invitation_restaurants", force: :cascade do |t|
    t.bigint "invitation_id", null: false
    t.bigint "restaurant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invitation_id", "restaurant_id"], name: "idx_on_invitation_id_restaurant_id_b09798ff19", unique: true
    t.index ["invitation_id"], name: "index_invitation_restaurants_on_invitation_id"
    t.index ["restaurant_id"], name: "index_invitation_restaurants_on_restaurant_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "invited_by_user_id"
    t.bigint "invited_by_admin_id"
    t.string "email_address", null: false
    t.string "role", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "accepted_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invited_by_admin_id"], name: "index_invitations_on_invited_by_admin_id"
    t.index ["invited_by_user_id"], name: "index_invitations_on_invited_by_user_id"
    t.index ["organization_id", "email_address", "accepted_at", "revoked_at"], name: "index_invitations_on_org_email_and_status"
    t.index ["organization_id"], name: "index_invitations_on_organization_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
  end

  create_table "menu_items", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.string "name", null: false
    t.text "description"
    t.decimal "price", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "available", default: true, null: false
    t.datetime "archived_at"
    t.index ["restaurant_id", "name"], name: "index_menu_items_on_restaurant_id_and_name", unique: true, where: "(archived_at IS NULL)"
    t.index ["restaurant_id"], name: "index_menu_items_on_restaurant_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "menu_item_id", null: false
    t.integer "quantity", null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "menu_item_name", null: false
    t.index ["menu_item_id"], name: "index_order_items_on_menu_item_id"
    t.index ["order_id", "menu_item_id"], name: "index_order_items_on_order_id_and_menu_item_id", unique: true
    t.index ["order_id"], name: "index_order_items_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "restaurant_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "customer_name"
    t.bigint "created_by_id"
    t.bigint "checkout_group_id"
    t.bigint "driver_id"
    t.string "delivery_status", default: "unassigned", null: false
    t.datetime "refunded_at"
    t.index ["checkout_group_id"], name: "index_orders_on_checkout_group_id", unique: true
    t.index ["created_by_id"], name: "index_orders_on_created_by_id"
    t.index ["driver_id", "delivery_status"], name: "index_orders_on_driver_id_and_delivery_status"
    t.index ["driver_id"], name: "index_orders_on_driver_id"
    t.index ["restaurant_id"], name: "index_orders_on_restaurant_id"
    t.index ["user_id"], name: "index_orders_on_user_id"
    t.check_constraint "delivery_status::text = ANY (ARRAY['unassigned'::character varying::text, 'assigned'::character varying::text, 'picked_up'::character varying::text, 'delivered'::character varying::text])", name: "orders_delivery_status_valid"
  end

  create_table "organization_memberships", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "user_id"], name: "index_organization_memberships_on_organization_id_and_user_id", unique: true
    t.index ["organization_id"], name: "index_organization_memberships_on_organization_id"
    t.index ["user_id"], name: "index_organization_memberships_on_user_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "time_zone", default: "UTC", null: false
  end

  create_table "report_deliveries", force: :cascade do |t|
    t.bigint "report_id", null: false
    t.bigint "user_id", null: false
    t.datetime "emailed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["report_id", "user_id"], name: "index_report_deliveries_unique", unique: true
    t.index ["report_id"], name: "index_report_deliveries_on_report_id"
    t.index ["user_id"], name: "index_report_deliveries_on_user_id"
  end

  create_table "report_schedule_categories", force: :cascade do |t|
    t.bigint "report_schedule_id", null: false
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["report_schedule_id", "category"], name: "index_report_schedule_categories_unique", unique: true
    t.index ["report_schedule_id"], name: "index_report_schedule_categories_on_report_schedule_id"
  end

  create_table "report_schedule_recipients", force: :cascade do |t|
    t.bigint "report_schedule_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["report_schedule_id", "user_id"], name: "index_report_schedule_recipients_unique", unique: true
    t.index ["report_schedule_id"], name: "index_report_schedule_recipients_on_report_schedule_id"
    t.index ["user_id"], name: "index_report_schedule_recipients_on_user_id"
  end

  create_table "report_schedules", force: :cascade do |t|
    t.bigint "organization_id", null: false
    t.bigint "restaurant_id"
    t.bigint "user_id", null: false
    t.string "cadence", null: false
    t.time "run_at", default: "2000-01-01 08:00:00", null: false
    t.boolean "active", default: true, null: false
    t.datetime "next_run_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active", "next_run_at"], name: "index_report_schedules_on_active_and_next_run_at"
    t.index ["organization_id"], name: "index_report_schedules_on_organization_id"
    t.index ["restaurant_id"], name: "index_report_schedules_on_restaurant_id"
    t.index ["user_id"], name: "index_report_schedules_on_user_id"
  end

  create_table "reports", force: :cascade do |t|
    t.bigint "requester_id", null: false
    t.bigint "organization_id", null: false
    t.bigint "restaurant_id"
    t.bigint "report_schedule_id"
    t.string "category", null: false
    t.string "status", default: "queued", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.datetime "completed_at"
    t.datetime "expires_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "created_at"], name: "index_reports_on_organization_id_and_created_at"
    t.index ["organization_id"], name: "index_reports_on_organization_id"
    t.index ["report_schedule_id"], name: "index_reports_on_report_schedule_id"
    t.index ["requester_id"], name: "index_reports_on_requester_id"
    t.index ["restaurant_id", "created_at"], name: "index_reports_on_restaurant_id_and_created_at"
    t.index ["restaurant_id"], name: "index_reports_on_restaurant_id"
    t.index ["status", "expires_at"], name: "index_reports_on_status_and_expires_at"
  end

  create_table "restaurant_memberships", force: :cascade do |t|
    t.bigint "restaurant_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["restaurant_id", "user_id"], name: "index_restaurant_memberships_on_restaurant_id_and_user_id", unique: true
    t.index ["restaurant_id"], name: "index_restaurant_memberships_on_restaurant_id"
    t.index ["user_id"], name: "index_restaurant_memberships_on_user_id"
  end

  create_table "restaurants", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "address_line1"
    t.string "city"
    t.string "region"
    t.string "postal_code"
    t.string "country_code"
    t.string "google_place_id"
    t.string "stripe_account_id"
    t.datetime "stripe_account_onboarded_at"
    t.decimal "delivery_base_fee", precision: 10, scale: 2
    t.decimal "delivery_fee_per_km", precision: 10, scale: 2
    t.decimal "max_delivery_distance_km", precision: 8, scale: 2
    t.bigint "organization_id", null: false
    t.index ["organization_id"], name: "index_restaurants_on_organization_id"
    t.index ["stripe_account_id"], name: "index_restaurants_on_stripe_account_id", unique: true
    t.check_constraint "delivery_base_fee IS NULL OR delivery_base_fee >= 0::numeric", name: "restaurants_delivery_base_fee_nonnegative"
    t.check_constraint "delivery_fee_per_km IS NULL OR delivery_fee_per_km >= 0::numeric", name: "restaurants_delivery_fee_per_km_nonnegative"
    t.check_constraint "max_delivery_distance_km IS NULL OR max_delivery_distance_km > 0::numeric", name: "restaurants_delivery_radius_positive"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "order_id", null: false
    t.string "reviewable_type", null: false
    t.bigint "reviewable_id", null: false
    t.integer "rating", null: false
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id", "reviewable_type", "reviewable_id"], name: "index_reviews_on_order_and_reviewable", unique: true
    t.index ["order_id"], name: "index_reviews_on_order_id"
    t.index ["reviewable_type", "reviewable_id"], name: "index_reviews_on_reviewable_type_and_reviewable_id"
    t.index ["user_id"], name: "index_reviews_on_user_id"
    t.check_constraint "rating >= 1 AND rating <= 5", name: "reviews_rating_in_range"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "admin_id"
    t.index ["admin_id"], name: "index_sessions_on_admin_id"
    t.index ["user_id"], name: "index_sessions_on_user_id"
    t.check_constraint "user_id IS NOT NULL AND admin_id IS NULL OR user_id IS NULL AND admin_id IS NOT NULL", name: "sessions_belong_to_one_account"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.string "role", default: "customer", null: false
    t.string "name"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "role::text = ANY (ARRAY['customer'::character varying::text, 'staff'::character varying::text, 'driver'::character varying::text])", name: "users_role_check"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cart_items", "carts"
  add_foreign_key "cart_items", "menu_items"
  add_foreign_key "carts", "users"
  add_foreign_key "checkout_groups", "checkouts"
  add_foreign_key "checkout_groups", "restaurants"
  add_foreign_key "checkout_items", "checkout_groups"
  add_foreign_key "checkout_items", "menu_items"
  add_foreign_key "checkouts", "users"
  add_foreign_key "invitation_restaurants", "invitations"
  add_foreign_key "invitation_restaurants", "restaurants"
  add_foreign_key "invitations", "admins", column: "invited_by_admin_id"
  add_foreign_key "invitations", "organizations"
  add_foreign_key "invitations", "users", column: "invited_by_user_id"
  add_foreign_key "menu_items", "restaurants"
  add_foreign_key "order_items", "menu_items"
  add_foreign_key "order_items", "orders"
  add_foreign_key "orders", "checkout_groups"
  add_foreign_key "orders", "restaurants"
  add_foreign_key "orders", "users"
  add_foreign_key "orders", "users", column: "created_by_id"
  add_foreign_key "orders", "users", column: "driver_id"
  add_foreign_key "organization_memberships", "organizations"
  add_foreign_key "organization_memberships", "users"
  add_foreign_key "report_deliveries", "reports", on_delete: :cascade
  add_foreign_key "report_deliveries", "users"
  add_foreign_key "report_schedule_categories", "report_schedules", on_delete: :cascade
  add_foreign_key "report_schedule_recipients", "report_schedules", on_delete: :cascade
  add_foreign_key "report_schedule_recipients", "users"
  add_foreign_key "report_schedules", "organizations"
  add_foreign_key "report_schedules", "restaurants"
  add_foreign_key "report_schedules", "users"
  add_foreign_key "reports", "organizations"
  add_foreign_key "reports", "report_schedules", on_delete: :nullify
  add_foreign_key "reports", "restaurants"
  add_foreign_key "reports", "users", column: "requester_id"
  add_foreign_key "restaurant_memberships", "restaurants"
  add_foreign_key "restaurant_memberships", "users"
  add_foreign_key "restaurants", "organizations"
  add_foreign_key "reviews", "orders"
  add_foreign_key "reviews", "users"
  add_foreign_key "sessions", "admins"
  add_foreign_key "sessions", "users"
end
