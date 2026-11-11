class SearchController < ApplicationController
  layout :search_layout
  allow_unauthenticated_access
  before_action :resume_session
  helper_method :result_path, :result_title, :result_description

  def index
    return head :bad_request if params[:type].present? && !Search::Results::TYPE_LABELS.key?(params[:type])
    organization_ids = accessible_organization_ids
    return redirect_to organizations_path if organization_admin_account? && organization_ids.empty?
    Current.organization = Organization.find(organization_ids.first) if organization_admin_account?
    page = Integer((params[:page].presence || 1).to_s, 10)
    return head :bad_request unless page.positive?

    @query = params[:q].to_s.strip
    @type = params[:type].presence
    @search = Search::Results.new(
      account: Current.account,
      query: @query,
      type: @type,
      organization_ids:,
      page:
    )
    @groups = @search.groups
    @type_options = @search.available_types.map { |type| [ Search::Results::TYPE_LABELS.fetch(type), type ] }
  rescue ArgumentError, TypeError
    head :bad_request
  end

  def result_path(type, record)
    case type
    when "organizations"
      if Current.account&.admin?
        admin_organizations_path(q: record.name, anchor: "organization-#{record.id}")
      else
        edit_organization_admin_profile_path
      end
    when "restaurants"
      if Current.account&.admin?
        edit_admin_restaurant_path(record)
      elsif Current.user.is_a?(User) && Current.user.organization_admin?
        edit_organization_admin_restaurant_path(record)
      else
        restaurant_path(record)
      end
    when "drivers"
      if Current.account&.admin?
        admin_drivers_path(q: record.name, anchor: "driver-#{record.id}")
      else
        organization_admin_order_history_path(q: record.name)
      end
    when "orders"
      if Current.account&.admin?
        admin_order_history_path(q: record.id, anchor: "order-#{record.id}")
      elsif Current.user.is_a?(User) && Current.user.organization_admin?
        organization_admin_order_history_path(q: record.id, anchor: "order-#{record.id}")
      else
        order_path(record)
      end
    when "deliveries"
      if Current.account&.admin?
        admin_order_history_path(q: record.id, anchor: "order-#{record.id}")
      elsif Current.user.is_a?(User) && Current.user.organization_admin?
        organization_admin_order_history_path(q: record.id, anchor: "order-#{record.id}")
      elsif Current.user.is_a?(User) && Current.user.driver?
        driver_root_path(q: record.id, anchor: "order-#{record.id}")
      end
    when "reviews"
      if Current.account&.admin?
        admin_reviews_path(q: @query, anchor: "review-#{record.id}")
      elsif Current.user.is_a?(User) && Current.user.organization_admin?
        organization_admin_reviews_path(q: @query, anchor: "review-#{record.id}")
      else
        order_path(record.order_id)
      end
    end
  end

  def result_title(type, record)
    case type
    when "organizations", "restaurants", "drivers"
      record.name
    when "orders"
      "Order ##{record.id}"
    when "deliveries"
      "Delivery · Order ##{record.id}"
    when "reviews"
      "#{record.reviewable.name} · #{record.rating}/5"
    end
  end

  def result_description(type, record)
    case type
    when "organizations"
      view_context.pluralize(record.restaurants.size, "restaurant")
    when "restaurants"
      record.city.presence || "Restaurant"
    when "drivers"
      record.email_address if Current.account&.admin?
    when "orders", "deliveries"
      "#{record.restaurant.name} · #{record.status.humanize} · #{record.delivery_status.humanize}"
    when "reviews"
      "By #{record.user.name.presence || "Customer"} · Order ##{record.order_id}"
    end
  end

  private

  def search_layout
    Current.account&.admin? ? "admin" : "application"
  end

  def accessible_organization_ids
    return [] unless organization_admin_account?

    organizations = Current.user.administered_organizations
    selected_organization = organizations.find_by(id: session[:organization_id])
    selected_organization ? [ selected_organization.id ] : []
  end

  def organization_admin_account?
    Current.user.is_a?(User) && Current.user.organization_admin?
  end
end
