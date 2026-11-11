class ReportsController < ApplicationController
  before_action :require_management_access
  before_action :set_report, only: %i[show download]

  def index
    load_index_data
  end

  def create
    organization, restaurant = Reports::Access.resolve_scope(Current.user, params[:scope])
    requested_categories = Array(params[:categories]).uniq
    categories = requested_categories.intersection(Report::CATEGORIES.values)
    start_date = parse_date(params[:start_date])
    end_date = parse_date(params[:end_date])

    if categories.empty? || categories.length != requested_categories.length || start_date.nil? || end_date.nil?
      load_index_data
      @form_error = "Choose at least one report category and a valid date range."
      return render :index, status: :unprocessable_entity
    end

    reports = Report.transaction do
      categories.map do |category|
        report = Report.create!(
          requester: Current.user,
          organization: organization,
          restaurant: restaurant,
          category: category,
          start_date: start_date,
          end_date: end_date
        )
        report.report_deliveries.create!(user: Current.user)
        report
      end
    end

    queued_count = reports.count { |report| Reports::EnqueueGeneration.call(report) }
    if queued_count == reports.length
      redirect_to reports_path, notice: "#{queued_count} report#{'s' if queued_count != 1} queued."
    else
      redirect_to reports_path, alert: "#{reports.length - queued_count} report#{'s' if reports.length - queued_count != 1} could not be queued. See the failed report status for details."
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  rescue ActiveRecord::RecordInvalid => error
    load_index_data
    @form_error = error.record.errors.full_messages.to_sentence
    render :index, status: :unprocessable_entity
  end

  def show
  end

  def download
    return head :not_found unless @report.downloadable?

    send_data @report.file.download, filename: @report.filename, type: "text/csv", disposition: "attachment"
  end

  private

  def require_management_access
    return if Current.user.is_a?(User) && (Current.user.staff? || Current.user.organization_admin?)

    head :forbidden
  end

  def set_report
    organization_ids = Reports::Access.organizations_for(Current.user).select(:id)
    restaurant_ids = Reports::Access.restaurants_for(Current.user).select(:id)
    @report = Report.where(organization_id: organization_ids, restaurant_id: nil)
      .or(Report.where(restaurant_id: restaurant_ids))
      .find(params[:id])
  end

  def load_index_data
    @scope_options = Reports::Access.scopes_for(Current.user)
    @selected_scope = params[:scope].presence || @scope_options.first&.last
    @recipient_options_by_scope = @scope_options.to_h do |_label, key|
      organization, restaurant = Reports::Access.resolve_scope(Current.user, key)
      [ key, Reports::Access.users_for_scope(organization: organization, restaurant: restaurant).to_a ]
    end
    @reports = Report.where(
      organization_id: Reports::Access.organizations_for(Current.user).select(:id),
      restaurant_id: nil
    ).or(Report.where(restaurant_id: Reports::Access.restaurants_for(Current.user).select(:id)))
      .includes(:requester, :organization, :restaurant)
      .newest_first
      .limit(100)
    @schedules = ReportSchedule.where(
      organization_id: Reports::Access.organizations_for(Current.user).select(:id),
      restaurant_id: nil
    ).or(ReportSchedule.where(restaurant_id: Reports::Access.restaurants_for(Current.user).select(:id)))
      .includes(:organization, :restaurant, :user, :recipients)
      .order(:next_run_at)
    default_organization, = Reports::Access.resolve_scope(Current.user, @selected_scope) if @selected_scope
    default_zone = default_organization ? ActiveSupport::TimeZone[default_organization.time_zone] : Time.zone
    @default_end_date = Time.current.in_time_zone(default_zone).to_date - 1.day
    @default_start_date = @default_end_date - 29.days
    @categories = Report::CATEGORIES
  end

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value)
  rescue ArgumentError, TypeError
    nil
  end
end
