module Admin
  class CustomersController < BaseController
    before_action :set_customer, only: [:show, :edit, :update, :destroy]

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

    private

    def set_customer
      @customer = current_organization.users.customer.find(params[:id])
    end

    def customer_params
      params.require(:user).permit(:name, :email, :phone, :venmo_handle, :is_active)
    end
  end
end
