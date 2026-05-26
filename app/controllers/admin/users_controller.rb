module Admin
  class UsersController < BaseController
    before_action :set_user, only: [:edit, :update, :destroy, :test_push, :resync_pushover]

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

    # Send a one-off push directly to the staff user's Pushover user key
    # (bypassing groups). Diagnostic: if this lands, the key + their device
    # are good and any group-delivery problem is on the membership side.
    def test_push
      if @user.pushover_user_key.blank?
        redirect_to edit_admin_user_path(@user), alert: "No Pushover user key on file" and return
      end

      PushoverAdapter.send_message(
        group_key: @user.pushover_user_key,
        title:     "Marina Ops — test push",
        message:   "If you see this, your Pushover user key + device are working."
      )
      redirect_to edit_admin_user_path(@user),
        notice: "Test push sent — check your device in a few seconds."
    rescue PushoverAdapter::Error => e
      redirect_to edit_admin_user_path(@user),
        alert: "Pushover refused the test push: #{e.message}"
    end

    # Re-run add_user_to_group synchronously for every location this user
    # is currently subscribed to. Diagnostic + recovery for cases where the
    # original async sync job died or was lost.
    def resync_pushover
      if @user.pushover_user_key.blank?
        redirect_to edit_admin_user_path(@user), alert: "No Pushover user key on file" and return
      end

      results = @user.subscribed_locations.map do |loc|
        next "#{loc.name}: (no group key)" if loc.pushover_group_key.blank?
        begin
          PushoverAdapter.add_user_to_group(
            group_key: loc.pushover_group_key,
            user_key:  @user.pushover_user_key,
            memo:      "#{@user.name} (#{@user.role})"
          )
          "#{loc.name}: ✓"
        rescue PushoverAdapter::Error => e
          "#{loc.name}: ✗ #{e.message}"
        end
      end

      if results.empty?
        redirect_to edit_admin_user_path(@user), alert: "Not subscribed to any locations"
      else
        redirect_to edit_admin_user_path(@user), notice: "Pushover re-sync: #{results.join(' · ')}"
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
