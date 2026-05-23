class DashboardController < ApplicationController
  before_action :authenticate!
  before_action :authorize_staff!

  def index
    @locations = current_organization.locations.active.order(:name)
    @location = current_organization.locations.find_by(id: params[:location_id]) || @locations.first
    @date = (Date.parse(params[:date]) if params[:date].present?) rescue nil
    @assignee_id = params[:assignee_id]
    @helpers = current_organization.users.staff.active.order(:name)
    @columns = { "to_do" => [], "in_progress" => [], "completed" => [] }

    return unless @location
    base = Request.for_location(@location)
                  .includes(:boat, :customer, :request_type, :assigned_to)
    base = base.where(assigned_to_id: @assignee_id) if @assignee_id.present?

    if @date
      day_scoped = base.scheduled_on(@date, @location.timezone)
      @columns = {
        "to_do"       => day_scoped.where(status: "to_do").order(:scheduled_for),
        "in_progress" => day_scoped.where(status: "in_progress").order(:scheduled_for),
        "completed"   => day_scoped.where(status: "completed").order(:scheduled_for)
      }
    else
      # "All dates" default: show full open pipeline + recent completed (cap so the
      # column doesn't grow unbounded over time).
      @columns = {
        "to_do"       => base.where(status: "to_do").order(:scheduled_for),
        "in_progress" => base.where(status: "in_progress").order(:scheduled_for),
        "completed"   => base.where(status: "completed")
                              .where("completed_at >= ?", 30.days.ago)
                              .order(completed_at: :desc)
      }
    end
  end

  def day
    @locations = current_organization.locations.active.order(:name)
    @location = current_organization.locations.find_by(id: params[:location_id]) || @locations.first
    @date = (Date.parse(params[:date]) rescue Date.current)
    @requests = []
    @open_hour, @close_hour = 7, 18
    @closed = true
    return unless @location

    @requests = Request.for_location(@location).scheduled_on(@date, @location.timezone)
                       .active.sorted.includes(:boat, :customer, :request_type, :assigned_to)
    h = @location.hours_for(@date.wday)
    @open_hour  = h&.open_time&.hour  || 7
    @close_hour = h&.close_time&.hour || 18
    @closed = h.nil? || h.closed?
  end

  def week
    @locations = current_organization.locations.active.order(:name)
    @location = current_organization.locations.find_by(id: params[:location_id]) || @locations.first
    start_date = (Date.parse(params[:start_date]) rescue Date.current).beginning_of_week(:monday)
    @week_dates = (0..6).map { |i| start_date + i }
    @counts_by_day = @week_dates.index_with { 0 }
    @start_date = start_date
    return unless @location

    base = Request.for_location(@location).active
    @week_dates.each do |d|
      @counts_by_day[d] = base.scheduled_on(d, @location.timezone).count
    end
  end
end
