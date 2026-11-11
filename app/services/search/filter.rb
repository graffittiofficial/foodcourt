module Search
  class Filter
    class << self
      def organizations(scope, query)
        return scope if query.blank?

        scope.where("organizations.name ILIKE ?", pattern(query))
      end

      def restaurants(scope, query)
        return scope if query.blank?

        scope.where("restaurants.name ILIKE :pattern OR restaurants.city ILIKE :pattern", pattern: pattern(query))
      end

      def drivers(scope, query)
        return scope if query.blank?

        scope.where(
          "users.name ILIKE :pattern OR users.email_address ILIKE :pattern",
          pattern: pattern(query)
        )
      end

      def orders(scope, query, include_driver: true)
        return scope if query.blank?

        matching_restaurants = restaurants(Restaurant.all, query).select(:id).to_sql
        matching_drivers = if include_driver
          drivers(User.driver, query).select(:id).to_sql
        else
          User.none.select(:id).to_sql
        end

        scope.where(
          <<~SQL.squish,
            CAST(orders.id AS TEXT) ILIKE :pattern
            OR orders.status ILIKE :pattern
            OR orders.delivery_status ILIKE :pattern
            OR orders.restaurant_id IN (#{matching_restaurants})
            OR orders.driver_id IN (#{matching_drivers})
          SQL
          pattern: pattern(query)
        )
      end

      def reviews(scope, query)
        return scope if query.blank?

        matching_reviewers = User.where(
          "users.name ILIKE :pattern OR users.email_address ILIKE :pattern",
          pattern: pattern(query)
        ).select(:id).to_sql
        matching_restaurants = restaurants(Restaurant.all, query).select(:id).to_sql
        matching_menu_items = MenuItem.where("menu_items.name ILIKE ?", pattern(query)).select(:id).to_sql

        scope.where(
          <<~SQL.squish,
            reviews.body ILIKE :pattern
            OR CAST(reviews.rating AS TEXT) ILIKE :pattern
            OR reviews.user_id IN (#{matching_reviewers})
            OR (reviews.reviewable_type = 'Restaurant' AND reviews.reviewable_id IN (#{matching_restaurants}))
            OR (reviews.reviewable_type = 'MenuItem' AND reviews.reviewable_id IN (#{matching_menu_items}))
          SQL
          pattern: pattern(query)
        )
      end

      private

      def pattern(query)
        "%#{ActiveRecord::Base.sanitize_sql_like(query.to_s.strip)}%"
      end
    end
  end
end
