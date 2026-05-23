class AuthController < ApplicationController
  layout "unauthenticated"

  def login
    redirect_to root_path and return if signed_in?
  end

  def create_token
    identifier = params[:identifier].to_s.strip
    password   = params[:password].to_s
    user = User.lookup_by_login(identifier)

    # Password path: if a password was provided, try direct sign-in.
    # On failure, always return a generic error (no user enumeration).
    if password.present?
      if user&.is_active? && user.password_digest.present? && user.authenticate(password)
        sign_in!(user)
        return redirect_to after_sign_in_path(user), notice: "Welcome back, #{user.name}"
      else
        # Burn an equivalent bcrypt cost so attackers can't distinguish
        # "unknown user" from "user with no password" from "wrong password"
        # via response timing.
        BCrypt::Password.create("dummy") if user.nil? || user.password_digest.blank?
        return redirect_to login_path, alert: "That email or password is incorrect."
      end
    end

    # Magic-link / SMS-code path (existing flow)
    if user&.is_active?
      channel = identifier.include?("@") ? "email" : "sms"
      raw, code = AuthToken.generate!(user: user, channel: channel,
                                      ip: request.remote_ip, ua: request.user_agent)
      if channel == "email"
        AuthMailer.with(user: user, token: raw).magic_link.deliver_later
      else
        SmsSenderJob.perform_later(
          to: user.phone,
          body: "Your marina sign-in code: #{code} (expires in 15 minutes)"
        )
      end
      session[:pending_user_id] = user.id if channel == "sms"
    end

    # Always show generic success to prevent enumeration
    redirect_to login_check_path(channel: identifier.include?("@") ? "email" : "sms")
  end

  def check
    @channel = params[:channel].presence_in(%w[email sms]) || "email"
  end

  def verify_link
    user = AuthToken.consume_by_token(params[:token])
    if user
      sign_in!(user)
      redirect_to after_sign_in_path(user), notice: "Welcome back, #{user.name}"
    else
      redirect_to login_path, alert: "That link is invalid or has expired. Please request a new one."
    end
  end

  def verify_code
    user_id = session[:pending_user_id]
    user = User.find_by(id: user_id) if user_id
    user = AuthToken.consume_by_code(user: user, code: params[:code])
    if user
      session.delete(:pending_user_id)
      sign_in!(user)
      redirect_to after_sign_in_path(user), notice: "Welcome back, #{user.name}"
    else
      redirect_to login_check_path(channel: "sms"), alert: "Invalid or expired code"
    end
  end

  def destroy
    sign_out!
    redirect_to login_path, notice: "Signed out"
  end

  # Dev-only quick login. Refuses to run outside development to avoid an
  # accidental backdoor in staging/production deploys.
  def dev_login
    head :forbidden and return unless Rails.env.development?

    org = Organization.first
    email = case params[:as].to_s
            when "manager"  then ENV.fetch("SEED_MANAGER_EMAIL", "manager@example.com")
            when "helper"   then "helper@example.com"
            when "customer" then "customer@example.com"
            end
    user = email && org&.users&.find_by(email: email)

    if user
      sign_in!(user)
      redirect_to after_sign_in_path(user), notice: "Signed in as #{user.name} (dev)"
    else
      redirect_to login_path, alert: "Dev user '#{params[:as]}' not found — run `bin/rails db:seed`"
    end
  end

  def sign_out_everywhere
    return redirect_to login_path unless signed_in?
    current_user.sessions.update_all(revoked_at: Time.current)
    sign_out!
    redirect_to login_path, notice: "Signed out of all devices"
  end

  private

  def after_sign_in_path(user)
    user.staff? ? dashboard_path : root_path
  end
end
