class AddStaffDashboardFields < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role, :string, null: false, default: "customer"
    add_reference :users, :restaurant, foreign_key: true
    add_check_constraint :users, "role IN ('customer', 'staff')", name: "users_role_check"
    add_check_constraint :users, "role <> 'staff' OR restaurant_id IS NOT NULL", name: "staff_users_require_restaurant"

    add_column :menu_items, :available, :boolean, null: false, default: true
    add_column :menu_items, :archived_at, :datetime

    change_column_null :orders, :user_id, true
    add_column :orders, :customer_name, :string
    add_reference :orders, :created_by, foreign_key: { to_table: :users }
  end
end
