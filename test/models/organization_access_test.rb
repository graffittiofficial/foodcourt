require "test_helper"

class OrganizationAccessTest < ActiveSupport::TestCase
  setup do
    @organization = create_organization(name: "Foodcourt Group")
    @restaurant = create_restaurant(name: "Corner Table", organization: @organization)
    @other_restaurant = create_restaurant(name: "Little Napoli", organization: @organization)
    @staff = create_staff(email_address: "staff@example.test", restaurants: [ @restaurant, @other_restaurant ])
  end

  test "every Restaurant must belong to an Organization" do
    assert_not Restaurant.new(name: "Unassigned").valid?
  end

  test "staff may manage several Restaurants within one Organization" do
    assert_equal [ @restaurant, @other_restaurant ].sort_by(&:id), @staff.restaurants.order(:id).to_a
    assert @staff.customer?
    assert @staff.staff?
  end

  test "staff cannot be assigned across Organizations" do
    other_organization = create_organization(name: "Another Group")
    other_restaurant = create_restaurant(name: "Other", organization: other_organization)
    membership = RestaurantMembership.new(user: @staff, restaurant: other_restaurant)

    assert_not membership.valid?
    assert_includes membership.errors[:user], "cannot be staff across multiple Organizations"
  end

  test "Drivers cannot receive management memberships" do
    driver = User.create!(
      name: "Delivery Driver",
      email_address: "driver@example.test",
      password: "password",
      role: :driver
    )
    membership = RestaurantMembership.new(user: driver, restaurant: @restaurant)

    assert_not membership.valid?
    assert_includes membership.errors[:user], "cannot be Restaurant staff while assigned as a Driver"
  end

  test "Organization admins manage all Restaurants and cannot remove the last admin" do
    organization_admin = User.create!(email_address: "org-admin@example.test", password: "password")
    membership = OrganizationMembership.create!(organization: @organization, user: organization_admin)

    assert organization_admin.organization_admin_for?(@organization)
    assert RestaurantMembership.create!(restaurant: @restaurant, user: organization_admin)
    assert Order.new(restaurant: @restaurant, customer_name: "Walk-in", created_by: organization_admin).valid?

    membership.destroy
    assert_not membership.destroyed?
    assert_includes membership.errors[:base], "An Organization must have at least one active admin."
  end

  test "a second Organization admin allows removal of the first" do
    first = User.create!(email_address: "first-admin@example.test", password: "password")
    second = User.create!(email_address: "second-admin@example.test", password: "password")
    first_membership = OrganizationMembership.create!(organization: @organization, user: first)
    OrganizationMembership.create!(organization: @organization, user: second)

    first_membership.destroy!

    assert_not first.organization_admin_for?(@organization)
    assert second.organization_admin_for?(@organization)
  end
end
