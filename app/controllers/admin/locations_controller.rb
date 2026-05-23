module Admin
  class LocationsController < BaseController
    before_action :set_location, only: [:show, :edit, :update, :destroy]

    def index
      @locations = current_organization.locations.order(:name)
    end

    def show
      @hours = (0..6).map { |d| @location.hours_for(d) || @location.location_hours.new(day_of_week: d) }
      @slips_by_type = @location.slips.group(:slip_type).count
    end

    def new
      @location = current_organization.locations.new(timezone: "America/Chicago", soft_cap_per_hour: 6)
      0.upto(6) { |d| @location.location_hours.build(day_of_week: d, open_time: "07:00", close_time: "18:00") }
    end

    def create
      @location = current_organization.locations.new(location_params)
      @location.slug = @location.name.to_s.parameterize if @location.slug.blank?
      if @location.save
        redirect_to admin_location_path(@location), notice: "Location created"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      existing = @location.location_hours.index_by(&:day_of_week)
      0.upto(6) do |d|
        @location.location_hours.build(day_of_week: d, open_time: "07:00", close_time: "18:00") unless existing[d]
      end
    end

    def update
      if @location.update(location_params)
        redirect_to admin_location_path(@location), notice: "Location updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @location.boats.exists? || @location.requests.exists?
        redirect_to admin_locations_path, alert: "Cannot delete a location with boats or requests"
      else
        @location.destroy
        redirect_to admin_locations_path, notice: "Location removed"
      end
    end

    private

    def set_location
      @location = current_organization.locations.find(params[:id])
    end

    def location_params
      params.require(:location).permit(:name, :slug, :address, :timezone, :soft_cap_per_hour, :is_active,
        location_hours_attributes: [:id, :day_of_week, :open_time, :close_time, :closed])
    end
  end
end
