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
      if validate_pushover_key(@user) && @user.save
        sync_subscriptions(@user)
        redirect_to admin_users_path, notice: "Staff member added"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      @user.assign_attributes(user_params)
      if validate_pushover_key(@user) && @user.save
        sync_subscriptions(@user)
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
      perm = params.require(:user).permit(:name, :email, :phone, :is_active, :pushover_user_key)
      submitted_role = params.dig(:user, :role).to_s
      perm[:role] = submitted_role if STAFF_ROLES.include?(submitted_role)
      perm
    end

    # Drive subscriptions through explicit destroy/create so the
    # after_destroy_commit and after_create_commit callbacks on
    # LocationSubscription fire (assignment via `subscribed_location_ids=`
    # uses raw SQL delete and skips them). Scoped to this org's locations
    # so a forged id can't subscribe to another org's group.
    def sync_subscriptions(user)
      submitted = Array(params.dig(:user, :subscribed_location_ids)).map(&:to_i).reject(&:zero?)
      allowed   = current_organization.locations.where(id: submitted).pluck(:id).to_set
      current   = user.location_subscriptions.reload.pluck(:location_id).to_set

      (current - allowed).each do |id|
        user.location_subscriptions.where(location_id: id).destroy_all
      end
      (allowed - current).each do |id|
        user.location_subscriptions.create!(location_id: id)
      end
    end

    # Verify the user key with Pushover before saving. In stub mode (no
    # PUSHOVER_APP_API_KEY) this short-circuits to true.
    def validate_pushover_key(user)
      key = user.pushover_user_key.to_s.strip
      return true if key.blank?
      return true if PushoverAdapter.validate_user(user_key: key)
      user.errors.add(:pushover_user_key, "is not a recognized Pushover user key")
      false
    end
  end
end
