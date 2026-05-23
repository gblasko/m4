class BoatsController < ApplicationController
  before_action :authenticate!

  def index
    if current_user.staff?
      redirect_to dashboard_path and return
    end
    @boats = current_user.boats.active.includes(:location, :slip).order(:name)
    # Soonest upcoming/active request per boat, for the at-a-glance status line.
    @next_request_by_boat = Request.where(boat_id: @boats.map(&:id))
                                    .open
                                    .where("scheduled_for >= ?", 1.hour.ago)
                                    .order(:scheduled_for)
                                    .includes(:request_type)
                                    .group_by(&:boat_id)
                                    .transform_values(&:first)
  end

  def show
    @boat = current_user.boats.find(params[:id])
    @recent_requests = @boat.requests.order(scheduled_for: :desc).limit(20).includes(:request_type)
  end
end
