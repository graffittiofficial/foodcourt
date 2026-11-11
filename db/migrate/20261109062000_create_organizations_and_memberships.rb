class CreateOrganizationsAndMemberships < ActiveRecord::Migration[8.1]
  def up
    create_table :organizations do |t|
      t.string :name, null: false
      t.timestamps
    end

    add_reference :restaurants, :organization, foreign_key: true

    create_table :organization_memberships do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :organization_memberships, [ :organization_id, :user_id ], unique: true

    create_table :restaurant_memberships do |t|
      t.references :restaurant, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :restaurant_memberships, [ :restaurant_id, :user_id ], unique: true

    Restaurant.reset_column_information
    User.reset_column_information

    Restaurant.find_each do |restaurant|
      organization = Organization.create!(name: "#{restaurant.name} Organization")
      restaurant.update!(organization: organization)
    end

    User.where(role: "staff").find_each do |user|
      next unless user[:restaurant_id]

      RestaurantMembership.create!(restaurant_id: user[:restaurant_id], user_id: user.id)
      user.update!(role: "customer")
    end

    remove_check_constraint :users, name: "staff_users_require_restaurant"
    remove_index :users, name: "index_users_on_restaurant_id"
    remove_foreign_key :users, :restaurants
    remove_column :users, :restaurant_id, :bigint
    change_column_null :restaurants, :organization_id, false
  end

  def down
    if OrganizationMembership.exists? ||
        RestaurantMembership.group(:user_id).having("COUNT(*) > 1").exists?
      raise ActiveRecord::IrreversibleMigration,
        "Organization and multi-Restaurant memberships cannot be represented by the legacy schema"
    end

    add_reference :users, :restaurant, foreign_key: true
    add_check_constraint :users, "role::text <> 'staff'::text OR restaurant_id IS NOT NULL", name: "staff_users_require_restaurant"

    User.reset_column_information
    RestaurantMembership.includes(:user).find_each do |membership|
      membership.user.update!(role: "staff", restaurant_id: membership.restaurant_id)
    end

    drop_table :restaurant_memberships
    drop_table :organization_memberships
    remove_reference :restaurants, :organization, foreign_key: true
    drop_table :organizations
  end
end
