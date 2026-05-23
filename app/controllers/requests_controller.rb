class RequestsController < ApplicationController
  before_action :authenticate!
  before_action :set_request, only: [:show, :update, :cancel, :note, :status, :assign]

  def index
    if current_user.staff?
      @requests = Request.joins(:location).where(locations: { organization_id: current_organization.id })
                          .includes(:boat, :customer, :request_type, :location, :assigned_to)
                          .order(scheduled_for: :desc).limit(100)
    else
      @requests = current_user.customer_requests.includes(:boat, :request_type, :location)
                              .order(scheduled_for: :desc)
    end
    @status = params[:status].presence
    @requests = @requests.where(status: @status) if @status
  end

  def show
    authorize_request_view!(@request)
    if current_user.staff?
      @timeline = build_timeline(@request)
    else
      @notes = @request.request_notes.public_notes.order(:created_at).includes(:author)
    end
  end

  def new
    authorize_role!(:customer)
    @boat = current_user.boats.find(params[:boat_id])
    @request = Request.new(boat: @boat, location: @boat.location, customer: current_user)
    @types = RequestType.applicable_for_boat(@boat).where(organization_id: current_organization.id)

    @min_date = Date.current.in_time_zone(@boat.location.timezone).to_date
    @max_date = @min_date + Request::MAX_HORIZON
    @initial_date = SlotBuilder.first_bookable_date(location: @boat.location, min_date: @min_date, max_date: @max_date)
    @initial_slots = SlotBuilder.call(location: @boat.location, date: @initial_date, step_minutes: 30)
  end

  def create
    authorize_role!(:customer)
    @boat = current_user.boats.find(params[:request][:boat_id])
    @request = Request.new(create_params.merge(
      customer: current_user, boat: @boat, location: @boat.location
    ))

    if @request.save
      AuditLog.record!(auditable: @request, action: "create", actor: current_user,
                        organization: current_organization, ip: request.remote_ip)
      NotificationService.dispatch(event: "request_submitted", request: @request, recipient: current_user)
      DashboardChannel.broadcast_create(@request)
      redirect_to request_path(@request), notice: "Request submitted"
    else
      @types = RequestType.applicable_for_boat(@boat).where(organization_id: current_organization.id)
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize_request_view!(@request)
    redirect_to request_path(@request) and return unless current_user.staff? || @request.customer == current_user

    if @request.editable? && @request.update(update_params)
      AuditLog.record!(auditable: @request, action: "update", actor: current_user,
                        organization: current_organization, ip: request.remote_ip)
      DashboardChannel.broadcast_update(@request)
      redirect_to request_path(@request), notice: "Request updated"
    else
      render :show, status: :unprocessable_entity
    end
  end

  def status
    authorize_staff!
    return unless @request.location.organization_id == current_organization.id

    target = params[:to].to_s

    if current_user.helper? && @request.assigned_to.present? && @request.assigned_to != current_user
      return respond_status_error("Helpers can only modify their own assignments")
    end

    begin
      case target
      when "in_progress" then @request.start!(actor: current_user)
      when "completed"   then @request.complete!(actor: current_user)
      when "cancelled"   then @request.cancel!(actor: current_user, reason: params[:reason])
      when "to_do"       then @request.unstart!(actor: current_user)
      else
        return respond_status_error("Invalid status")
      end
    rescue => e
      return respond_status_error(e.message)
    end

    AuditLog.record!(auditable: @request, action: "transition", actor: current_user,
                      organization: current_organization,
                      changes: { to: target }, ip: request.remote_ip)
    NotificationService.dispatch_for_status_change(@request)
    DashboardChannel.broadcast_update(@request)

    respond_to do |fmt|
      fmt.html { redirect_to request_path(@request), notice: "Status updated" }
      fmt.json { head :no_content }
    end
  end

  def assign
    authorize_staff!
    if current_user.helper? && params[:assigned_to_id].to_i != current_user.id
      return redirect_to request_path(@request), alert: "Helpers can only assign requests to themselves"
    end
    assignee = params[:assigned_to_id].present? ?
      current_organization.users.staff.find(params[:assigned_to_id]) : nil
    if @request.update(assigned_to: assignee)
      AuditLog.record!(auditable: @request, action: "assign", actor: current_user,
                        organization: current_organization,
                        changes: { assigned_to_id: assignee&.id }, ip: request.remote_ip)
      if assignee.present?
        NotificationService.dispatch(event: "request_assigned", request: @request, recipient: assignee)
      end
      DashboardChannel.broadcast_update(@request)
    end
    redirect_to request_path(@request)
  end

  def cancel
    authorize_request_view!(@request)
    if !@request.to_do? && current_user.customer?
      return redirect_to request_path(@request), alert: "You can only cancel requests that have not started"
    end
    if @request.completed?
      return redirect_to request_path(@request), alert: "Completed requests cannot be cancelled"
    end
    @request.cancel!(actor: current_user, reason: params[:reason])
    AuditLog.record!(auditable: @request, action: "transition", actor: current_user,
                      organization: current_organization,
                      changes: { to: "cancelled", reason: params[:reason] }, ip: request.remote_ip)
    NotificationService.dispatch(event: "request_cancelled", request: @request, recipient: @request.customer)
    DashboardChannel.broadcast_update(@request)
    redirect_to request_path(@request), notice: "Request cancelled"
  end

  def note
    authorize_request_view!(@request)
    visibility = (current_user.customer? ? "public" : (params[:visibility].presence || "private"))
    note = @request.request_notes.new(body: params[:body], visibility: visibility, author: current_user)
    if note.save
      AuditLog.record!(auditable: note, action: "create", actor: current_user,
                        organization: current_organization, ip: request.remote_ip)
      if visibility == "public" && @request.customer != current_user
        NotificationService.dispatch(event: "public_note_added", request: @request, recipient: @request.customer)
      end
      redirect_to request_path(@request), notice: "Note added"
    else
      redirect_to request_path(@request), alert: note.errors.full_messages.to_sentence
    end
  end

  private

  # Merge notes + audit log into one chronological timeline for the staff view.
  def build_timeline(req)
    notes = req.request_notes.includes(:author).map do |n|
      { kind: :note, at: n.created_at, by: n.author, visibility: n.visibility, body: n.body }
    end
    events = AuditLog.where(auditable_type: "Request", auditable_id: req.id)
                     .includes(:actor).order(:created_at)
                     .map do |log|
      { kind: :event, at: log.created_at, by: log.actor, action: log.action, changes: log.changes_data }
    end
    (notes + events).sort_by { |i| i[:at] }
  end

  def respond_status_error(message)
    respond_to do |fmt|
      fmt.html { redirect_to request_path(@request), alert: message }
      fmt.json { render json: { error: message }, status: :unprocessable_entity }
    end
  end

  def set_request
    @request = Request.find(params[:id])
  end

  def authorize_request_view!(req)
    return if current_user.staff? && req.location.organization_id == current_organization.id
    return if req.customer_id == current_user.id
    render file: Rails.root.join("public/403.html"), status: :forbidden, layout: false
  end

  def create_params
    params.require(:request).permit(:request_type_id, :scheduled_for, :description)
  end

  def update_params
    params.require(:request).permit(:description, :scheduled_for, :assigned_to_id)
  end
end
