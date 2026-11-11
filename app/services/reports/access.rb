module Reports
  class Access
    def self.can_access_scope?(user, organization:, restaurant: nil)
      return false unless user.is_a?(User) && organization
      return false if restaurant && restaurant.organization_id != organization.id

      if restaurant
        user.organization_admin_for?(organization) || user.staff_for?(restaurant)
      else
        user.organization_admin_for?(organization)
      end
    end

    def self.organizations_for(user)
      return Organization.none unless user.is_a?(User)

      user.administered_organizations
    end

    def self.restaurants_for(user)
      return Restaurant.none unless user.is_a?(User)

      Restaurant.where(id: user.restaurants.select(:id))
        .or(Restaurant.where(organization_id: user.administered_organizations.select(:id)))
    end

    def self.scopes_for(user)
      organizations = organizations_for(user).order(:name).map do |organization|
        [ "Organization: #{organization.name}", "organization:#{organization.id}" ]
      end
      restaurants = restaurants_for(user).includes(:organization).order(:name).map do |restaurant|
        [ "#{restaurant.organization.name} / #{restaurant.name}", "restaurant:#{restaurant.id}" ]
      end
      organizations + restaurants
    end

    def self.users_for_scope(organization:, restaurant: nil)
      admin_ids = organization.organization_memberships.select(:user_id)
      user_scope = User.where(id: admin_ids)
      user_scope = user_scope.or(User.where(id: restaurant.restaurant_memberships.select(:user_id))) if restaurant
      user_scope.distinct.order(:email_address)
    end

    def self.resolve_scope(user, key)
      kind, id = key.to_s.split(":", 2)
      case kind
      when "organization"
        organization = organizations_for(user).find_by(id: id)
        raise ActiveRecord::RecordNotFound unless organization

        [ organization, nil ]
      when "restaurant"
        restaurant = restaurants_for(user).includes(:organization).find_by(id: id)
        raise ActiveRecord::RecordNotFound unless restaurant

        [ restaurant.organization, restaurant ]
      else
        raise ActiveRecord::RecordNotFound
      end
    end
  end
end
