class LocationsController < ApplicationController
  before_action :authenticate!

  # JSON: returns slot availability for a given date
  # GET /locations/:id/availability?date=2026-05-23&step=30
  def availability
    @location = current_organization.locations.find(params[:id])
    date = (Date.parse(params[:date]) rescue Date.current)
    step_minutes = params[:step].to_i.then { |s| s.between?(5, 120) ? s : 30 }
    slots = SlotBuilder.call(location: @location, date: date, step_minutes: step_minutes)
    render json: {
      date: date.to_s,
      timezone: @location.timezone,
      step_minutes: step_minutes,
      slots: slots,
      closed: slots.empty?
    }
  end
end
