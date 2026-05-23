module Admin
  class SlipsController < BaseController
    before_action :set_location
    before_action :set_slip, only: [:edit, :update, :destroy]

    def index
      @slips = @location.slips.order(:slip_type, :label)
    end

    def new
      @slip = @location.slips.new(slip_type: "in_water")
    end

    def create
      @slip = @location.slips.new(slip_params)
      if @slip.save
        redirect_to admin_location_slips_path(@location), notice: "Slip added"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @slip.update(slip_params)
        redirect_to admin_location_slips_path(@location), notice: "Slip updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @slip.boats.exists?
        redirect_to admin_location_slips_path(@location), alert: "Slip has boats assigned"
      else
        @slip.destroy
        redirect_to admin_location_slips_path(@location), notice: "Slip removed"
      end
    end

    private

    def set_location
      @location = current_organization.locations.find(params[:location_id])
    end

    def set_slip
      @slip = @location.slips.find(params[:id])
    end

    def slip_params
      params.require(:slip).permit(:label, :slip_type, :is_active)
    end
  end
end
