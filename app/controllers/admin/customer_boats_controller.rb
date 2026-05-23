module Admin
  class CustomerBoatsController < BaseController
    before_action :set_customer
    before_action :set_boat, only: [:edit, :update, :destroy]

    def index
      @boats = @customer.boats.includes(:location, :slip).order(:name)
    end

    def new
      @boat = @customer.boats.new(location: current_organization.locations.active.first, storage_type: "in_water")
    end

    def create
      @boat = @customer.boats.new(boat_params)
      if @boat.save
        AuditLog.record!(auditable: @boat, action: "create", actor: current_user,
                          organization: current_organization, changes: @boat.previous_changes.except("updated_at"),
                          ip: request.remote_ip)
        redirect_to admin_customer_path(@customer), notice: "Boat added"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @boat.update(boat_params)
        AuditLog.record!(auditable: @boat, action: "update", actor: current_user,
                          organization: current_organization, changes: @boat.previous_changes.except("updated_at"),
                          ip: request.remote_ip)
        redirect_to admin_customer_path(@customer), notice: "Boat updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @boat.requests.exists?
        redirect_to admin_customer_path(@customer), alert: "Cannot delete a boat with requests"
      else
        @boat.destroy
        redirect_to admin_customer_path(@customer), notice: "Boat removed"
      end
    end

    private

    def set_customer
      @customer = current_organization.users.customer.find(params[:customer_id])
    end

    def set_boat
      @boat = @customer.boats.find(params[:id])
    end

    def boat_params
      params.require(:boat).permit(:name, :make, :model, :year, :length_ft, :storage_type,
                                    :location_id, :slip_id, :notes, :is_active)
    end
  end
end
