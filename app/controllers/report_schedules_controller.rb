class ReportSchedulesController < ApplicationController
  before_action :require_management_access
  before_action :set_schedule, only: %i[edit update pause resume destroy]
  before_action :require_schedule_management, only: %i[edit update pause resume destroy]

  def create
    organization, restaurant = Reports::Access.resolve_scope(Current.user, params[:scope])
    @schedule = ReportSchedule.new(
      organization: organization,
      restaurant: restaurant,
      user: Current.user,
      cadence: schedule_params[:cadence],
      run_at: schedule_params[:run_at]
    )
    assign_categories
    assign_recipients(organization, restaurant)
    if @schedule.errors.any?
      return redirect_to reports_path, alert: @schedule.errors.full_messages.to_sentence
    end

    unless valid_schedule_options?
      return redirect_to reports_path, alert: "Choose a valid cadence and local run time."
    end
    @schedule.next_run_at = @schedule.next_run_after(Time.current)
    if @schedule.save
      redirect_to reports_path, notice: "Report schedule created."
    else
      redirect_to reports_path, alert: @schedule.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def edit
    @scope_options = Reports::Access.scopes_for(Current.user)
    @selected_scope = scope_key(@schedule.organization, @schedule.restaurant)
    @categories = Report::CATEGORIES
    @selected_categories = @schedule.categories
    @recipient_options_by_scope = recipient_options_by_scope
    @selected_recipient_ids = @schedule.recipients.pluck(:id)
  end

  def update
    organization, restaurant = Reports::Access.resolve_scope(Current.user, params[:scope])
    selected_categories = requested_categories
    selected_recipients = requested_recipients(organization, restaurant)
    if selected_categories.empty? || selected_categories.length != Array(params[:categories]).uniq.length
      return redirect_to edit_report_schedule_path(@schedule), alert: "Select at least one valid report category."
    end
    if selected_recipients.empty? || selected_recipients.length != Array(params[:recipient_ids]).uniq.length
      return redirect_to edit_report_schedule_path(@schedule), alert: "Select at least one recipient with current access to this scope."
    end
    unless valid_schedule_options?
      return redirect_to edit_report_schedule_path(@schedule), alert: "Choose a valid cadence and local run time."
    end

    @schedule.assign_attributes(
      organization: organization,
      restaurant: restaurant,
      cadence: schedule_params[:cadence],
      run_at: schedule_params[:run_at]
    )
    @schedule.next_run_at = @schedule.next_run_after(Time.current)

    saved = false
    ReportSchedule.transaction do
      @schedule.report_schedule_categories.destroy_all
      @schedule.report_schedule_recipients.destroy_all
      @schedule.association(:report_schedule_categories).reset
      @schedule.association(:report_schedule_recipients).reset
      selected_categories.each { |category| @schedule.report_schedule_categories.build(category: category) }
      selected_recipients.each { |recipient| @schedule.report_schedule_recipients.build(user: recipient) }
      saved = @schedule.save
      raise ActiveRecord::Rollback unless saved
    end

    if saved
      redirect_to reports_path, notice: "Report schedule updated."
    else
      @schedule.reload
      redirect_to edit_report_schedule_path(@schedule), alert: @schedule.errors.full_messages.to_sentence
    end
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def pause
    @schedule.update!(active: false)
    redirect_to reports_path, notice: "Report schedule paused."
  end

  def resume
    @schedule.update!(active: true, next_run_at: @schedule.next_run_after(Time.current))
    redirect_to reports_path, notice: "Report schedule resumed."
  end

  def destroy
    @schedule.destroy!
    redirect_to reports_path, notice: "Report schedule deleted."
  end

  private

  def require_management_access
    return if Current.user.is_a?(User) && (Current.user.staff? || Current.user.organization_admin?)

    head :forbidden
  end

  def set_schedule
    organization_ids = Reports::Access.organizations_for(Current.user).select(:id)
    restaurant_ids = Reports::Access.restaurants_for(Current.user).select(:id)
    @schedule = ReportSchedule.where(organization_id: organization_ids, restaurant_id: nil)
      .or(ReportSchedule.where(restaurant_id: restaurant_ids))
      .find(params[:id])
  end

  def require_schedule_management
    return if @schedule.manageable_by?(Current.user)

    head :forbidden
  end

  def schedule_params
    params.permit(:cadence, :run_at)
  end

  def assign_categories
    categories = requested_categories
    if categories.empty? || categories.length != Array(params[:categories]).uniq.length
      @schedule.errors.add(:base, "Select at least one valid report category.")
      return
    end

    categories.each do |category|
      @schedule.report_schedule_categories.build(category: category)
    end
  end

  def assign_recipients(organization, restaurant)
    recipients = requested_recipients(organization, restaurant)
    if recipients.empty? || recipients.length != Array(params[:recipient_ids]).uniq.length
      @schedule.errors.add(:base, "Select at least one recipient with current access to this scope.")
      return
    end

    recipients.each do |recipient|
      @schedule.report_schedule_recipients.build(user: recipient)
    end
  end

  def requested_categories
    Array(params[:categories]).uniq.intersection(Report::CATEGORIES.values)
  end

  def valid_schedule_options?
    ReportSchedule::CADENCES.value?(schedule_params[:cadence]) &&
      schedule_params[:run_at].to_s.match?(/\A(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?\z/)
  end

  def requested_recipients(organization, restaurant)
    Reports::Access.users_for_scope(organization: organization, restaurant: restaurant)
      .where(id: Array(params[:recipient_ids]).map(&:to_s).uniq)
      .to_a
  end

  def recipient_options_by_scope
    @scope_options.to_h do |_label, key|
      organization, restaurant = Reports::Access.resolve_scope(Current.user, key)
      [ key, Reports::Access.users_for_scope(organization: organization, restaurant: restaurant).to_a ]
    end
  end

  def scope_key(organization, restaurant)
    restaurant ? "restaurant:#{restaurant.id}" : "organization:#{organization.id}"
  end
end
