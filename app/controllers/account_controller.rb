class AccountController < ApplicationController
  before_action :authenticate!

  def show
  end

  def update
    prefs = params[:notification_prefs] || {}
    cleaned = {}
    User::DEFAULT_PREFS.each do |event, channels|
      cleaned[event] = channels.transform_keys(&:to_s).map { |ch, _|
        [ch, prefs.dig(event, ch).to_s.in?(%w[1 true on])]
      }.to_h
    end

    current_user.notification_prefs = cleaned
    current_user.assign_attributes(account_params)

    if current_user.save
      redirect_to account_path, notice: "Account updated"
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def account_params
    permitted = [:name, :email, :phone]
    permitted << :venmo_handle if current_user.staff?
    params.require(:user).permit(*permitted)
  end
end
