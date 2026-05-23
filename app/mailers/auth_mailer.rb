class AuthMailer < ApplicationMailer
  def magic_link
    @user = params[:user]
    @url = verify_link_url(token: params[:token])
    mail(to: @user.email, subject: "Your marina sign-in link")
  end
end
