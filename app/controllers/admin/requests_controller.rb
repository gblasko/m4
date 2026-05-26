module Admin
  # Staff create requests on behalf of a customer (phone-in, walk-up, text).
  # Open to both managers and helpers — not gated by Admin::BaseController.
  class RequestsController < ApplicationController
    before_action :authenticate!
    before_action :authorize_staff!

    def new
      @customers = current_organization.users.customer.active.order(:name)
      @customer = @customers.find_by(id: params[:customer_id])
      @boats = @customer ? @customer.boats.active.includes(:location, :slip).order(:name) : Boat.none
      @boat = @boats.find_by(id: params[:boat_id])

      return unless @boat

      @types = RequestType.applicable_for_boat(@boat).where(organization_id: current_organization.id)
      @min_date = Date.current.in_time_zone(@boat.location.timezone).to_date
      @max_date = @min_date + Request::MAX_HORIZON
      @initial_date = SlotBuilder.first_bookable_date(location: @boat.location, min_date: @min_date, max_date: @max_date)
      @initial_slots = SlotBuilder.call(location: @boat.location, date: @initial_date, step_minutes: 30)
      @request ||= Request.new(boat: @boat, customer: @customer, location: @boat.location)
    end

    def create
      @customer = current_organization.users.customer.find(params[:request][:customer_id])
      @boat = @customer.boats.find(params[:request][:boat_id])

      @request = Request.new(create_params.merge(
        customer: @customer, boat: @boat, location: @boat.location
      ))

      if @request.save
        AuditLog.record!(auditable: @request, action: "staff_create", actor: current_user,
                          organization: current_organization,
                          changes: { on_behalf_of: @customer.id }, ip: request.remote_ip)
        NotificationService.dispatch(event: "request_submitted", request: @request, recipient: @customer)
        NotificationService.dispatch_for_location(event: "request_submitted", request: @request)
        DashboardChannel.broadcast_create(@request)
        redirect_to request_path(@request), notice: "Request created for #{@customer.name}"
      else
        # Re-populate the form context so the rendered :new template has what it needs,
        # while preserving the invalid @request (with its errors).
        params[:customer_id] = @customer.id
        params[:boat_id] = @boat.id
        invalid = @request
        new
        @request = invalid
        render :new, status: :unprocessable_entity
      end
    end

    private

    def create_params
      params.require(:request).permit(:request_type_id, :scheduled_for, :description)
    end
  end
end
