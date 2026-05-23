module Admin
  class UsersController < BaseController
    before_action :set_user, only: [:edit, :update, :destroy]

    def index
      @users = current_organization.users.staff.order(:name)
    end

    def new
      @user = current_organization.users.new(role: :helper)
    end

    def create
      @user = current_organization.users.new(user_params)
      unless %w[manager helper].include?(@user.role.to_s)
        @user.role = :helper
      end
      if @user.save
        redirect_to admin_users_path, notice: "Staff member added"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @user.update(user_params)
        redirect_to admin_users_path, notice: "Staff member updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: "You cannot remove your own account"
      else
        @user.update(is_active: false)
        redirect_to admin_users_path, notice: "Staff member deactivated"
      end
    end

    private

    def set_user
      @user = current_organization.users.staff.find(params[:id])
    end

    STAFF_ROLES = %w[manager helper].freeze

    def user_params
      # Don't permit :role for mass assignment — validate it explicitly against
      # an allowlist so a tampered form can't push "customer" (or anything else)
      # through this staff-management endpoint.
      perm = params.require(:user).permit(:name, :email, :phone, :is_active)
      submitted_role = params.dig(:user, :role).to_s
      perm[:role] = submitted_role if STAFF_ROLES.include?(submitted_role)
      perm
    end
  end
end
