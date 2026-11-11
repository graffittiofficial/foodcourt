module Search
  class Results
    TYPE_LABELS = {
      "organizations" => "Organizations",
      "restaurants" => "Restaurants",
      "drivers" => "Drivers",
      "orders" => "Order history",
      "deliveries" => "Deliveries",
      "reviews" => "Reviews"
    }.freeze
    PAGE_SIZE = 10

    attr_reader :query

    def initialize(account:, query:, organization_ids: [], type: nil, page: 1)
      @account = account
      @query = query.to_s.strip
      @organization_ids = organization_ids
      @type = type.presence
      @page = page
    end

    def available_types
      if admin?
        TYPE_LABELS.keys
      elsif organization_admin?
        TYPE_LABELS.keys
      elsif driver?
        %w[deliveries]
      elsif customer?
        %w[restaurants orders reviews]
      elsif @account.nil? || staff?
        %w[restaurants]
      else
        []
      end
    end

    def groups
      return [] if query.blank?

      types = available_types
      types &= [ @type ] if @type
      types.map do |type|
        scope = records_for(type)
        total_count = scope.count
        total_pages = [ (total_count.to_f / PAGE_SIZE).ceil, 1 ].max
        page = @type ? [ @page, total_pages ].min : 1
        {
          type:,
          label: TYPE_LABELS.fetch(type),
          records: scope.limit(PAGE_SIZE).offset((page - 1) * PAGE_SIZE),
          total_count:,
          page:,
          total_pages:
        }
      end
    end

    private

    def records_for(type)
      case type
      when "organizations"
        scope = Organization.includes(:restaurants)
        scope = scope.where(id: @organization_ids) unless admin?
        Filter.organizations(scope, query).order(:name)
      when "restaurants"
        scope = Restaurant.all
        scope = scope.where(organization_id: @organization_ids) if organization_admin?
        scope = Restaurant.none if driver?
        Filter.restaurants(scope, query).order(:name)
      when "drivers"
        scope = if admin?
          User.driver
        elsif organization_admin?
          User.driver.where(id: scoped_orders.where.not(driver_id: nil).select(:driver_id))
        else
          User.none
        end
        Filter.drivers(scope, query).order(:name, :email_address)
      when "orders"
        scope = order_scope
        Filter.orders(scope, query, include_driver: !customer?).includes(:restaurant, :driver).order(created_at: :desc, id: :desc)
      when "deliveries"
        scope = delivery_scope
        Filter.orders(scope, query, include_driver: admin? || organization_admin?).includes(:restaurant, :driver).order(created_at: :desc, id: :desc)
      when "reviews"
        scope = review_scope
        Filter.reviews(scope, query).includes(:user, :order, :reviewable).order(created_at: :desc, id: :desc)
      else
        raise ArgumentError, "Unsupported search type: #{type}"
      end
    end

    def order_scope
      return Order.all if admin?
      return scoped_orders if organization_admin?
      return @account.orders if customer?

      Order.none
    end

    def delivery_scope
      return Order.where.not(checkout_group_id: nil) if admin?
      return scoped_orders.where.not(checkout_group_id: nil) if organization_admin?
      return @account.assigned_orders if driver?

      Order.none
    end

    def review_scope
      return Review.all if admin?
      return Review.where(order_id: scoped_orders.select(:id)) if organization_admin?
      return Review.where(user_id: @account.id) if customer?

      Review.none
    end

    def scoped_orders
      Order.where(restaurant_id: Restaurant.where(organization_id: @organization_ids).select(:id))
    end

    def admin?
      @account&.admin?
    end

    def organization_admin?
      @account.is_a?(User) && @account.organization_admin? && @organization_ids.any?
    end

    def driver?
      @account.is_a?(User) && @account.driver?
    end

    def customer?
      @account.is_a?(User) && @account.customer? && !@account.organization_admin? && !@account.staff?
    end

    def staff?
      @account.is_a?(User) && @account.staff?
    end
  end
end
