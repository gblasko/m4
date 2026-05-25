module Admin
  class CustomersController < BaseController
    before_action :set_customer, only: [:show, :edit, :update, :destroy, :invite]

    def index
      @customers = current_organization.users.customer.order(:name)
      @q = params[:q].to_s.strip
      if @q.present?
        like = "%#{@q.downcase}%"
        @customers = @customers.where("lower(name) LIKE ? OR lower(coalesce(email,'')) LIKE ? OR coalesce(phone,'') LIKE ?", like, like, "%#{@q}%")
      end
    end

    def show
      @boats = @customer.boats.includes(:location)
      @recent_requests = @customer.customer_requests.order(scheduled_for: :desc).limit(20).includes(:boat, :request_type)
    end

    def new
      @customer = current_organization.users.new(role: :customer)
    end

    def create
      @customer = current_organization.users.new(customer_params.merge(role: :customer))
      if @customer.save
        AuditLog.record!(auditable: @customer, action: "create", actor: current_user,
                          organization: current_organization, changes: @customer.previous_changes.except("updated_at"),
                          ip: request.remote_ip)
        redirect_to admin_customer_path(@customer), notice: "Customer created"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @customer.update(customer_params)
        AuditLog.record!(auditable: @customer, action: "update", actor: current_user,
                          organization: current_organization, changes: @customer.previous_changes.except("updated_at"),
                          ip: request.remote_ip)
        redirect_to admin_customer_path(@customer), notice: "Customer updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @customer.boats.exists? || @customer.customer_requests.exists?
        redirect_to admin_customers_path, alert: "Cannot delete a customer with boats or requests"
      else
        @customer.destroy
        AuditLog.record!(auditable: @customer, action: "destroy", actor: current_user,
                          organization: current_organization, ip: request.remote_ip)
        redirect_to admin_customers_path, notice: "Customer removed"
      end
    end

    # Send the customer a one-tap magic-link sign-in. `channel` is "email" or
    # "sms"; defaults to whichever contact method the customer has on file
    # (preferring email when both are present).
    def invite
      channel = params[:channel].to_s.presence_in(%w[email sms])
      channel ||= @customer.email.present? ? "email" : "sms"

      if channel == "email" && @customer.email.blank?
        redirect_to admin_customer_path(@customer), alert: "No email on file" and return
      elsif channel == "sms" && @customer.phone.blank?
        redirect_to admin_customer_path(@customer), alert: "No phone on file" and return
      end

      raw, _code = AuthToken.generate!(user: @customer, channel: channel,
                                       ip: request.remote_ip, ua: request.user_agent)
      url = verify_link_url(token: raw)

      if channel == "email"
        AuthMailer.with(user: @customer, url: url).invite.deliver_later
        sent_to = @customer.email
      else
        SmsSenderJob.perform_later(
          to: @customer.phone,
          body: "#{current_organization.name}: tap to sign in #{url} (Reply STOP to opt out)"
        )
        sent_to = @customer.phone
      end

      AuditLog.record!(auditable: @customer, action: "invite_sent", actor: current_user,
                        organization: current_organization,
                        changes: { channel: channel }, ip: request.remote_ip)
      redirect_to admin_customer_path(@customer),
        notice: "Invite sent via #{channel} to #{sent_to}"
    end

    private

    def set_customer
      @customer = current_organization.users.customer.find(params[:id])
    end

    def customer_params
      params.require(:user).permit(:name, :email, :phone, :venmo_handle, :is_active)
    end
  end
end
