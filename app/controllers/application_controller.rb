class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :load_current_session
  before_action :touch_session

  helper_method :current_user, :current_organization, :current_session, :signed_in?

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  SESSION_COOKIE = :marina_session

  def current_session
    @current_session
  end

  def current_user
    @current_user
  end

  def current_organization
    @current_organization ||= current_user&.organization || Organization.first
  end

  def signed_in?
    current_user.present?
  end

  def authenticate!
    return if signed_in?
    redirect_to login_path, alert: "Please sign in"
  end

  def authorize_role!(*roles)
    unless current_user && roles.map(&:to_s).include?(current_user.role)
      respond_to do |fmt|
        fmt.html { render file: Rails.root.join("public/403.html"), status: :forbidden, layout: false }
        fmt.json { render json: { error: "forbidden" }, status: :forbidden }
      end
    end
  end

  def authorize_staff!
    authorize_role!(:manager, :helper)
  end

  def authorize_manager!
    authorize_role!(:manager)
  end

  def sign_in!(user)
    raw = Session.start!(user: user, ip: request.remote_ip, ua: request.user_agent)
    cookies.encrypted[SESSION_COOKIE] = {
      value: raw,
      expires: Session::ABSOLUTE_TTL.from_now,
      httponly: true,
      secure: Rails.env.production?,
      same_site: :lax
    }
    @current_session = Session.find_active(raw)
    @current_user = user
    user.update_column(:last_seen_at, Time.current)
  end

  def sign_out!
    current_session&.revoke!
    cookies.delete(SESSION_COOKIE)
    @current_session = nil
    @current_user = nil
  end

  def load_current_session
    raw = cookies.encrypted[SESSION_COOKIE]
    @current_session = Session.find_active(raw)
    @current_user = @current_session&.user
    @current_organization = @current_user&.organization
  end

  def touch_session
    @current_session&.touch_rolling!
  end

  def layout_for_user
    return "unauthenticated" unless signed_in?
    current_user.staff? ? "staff" : "customer"
  end

  def render_not_found
    render file: Rails.root.join("public/404.html"), status: :not_found, layout: false
  end
end
