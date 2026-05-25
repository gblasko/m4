class AuthMailer < ApplicationMailer
  def magic_link
    @user = params[:user]
    @url = verify_link_url(token: params[:token])
    mail(to: @user.email, subject: "Your marina sign-in link")
  end

  # Staff-triggered invite. The caller passes a fully-formed verify URL so the
  # token plumbing stays in the controller that minted the token.
  def invite
    @user = params[:user]
    @url  = params[:url]
    mail(to: @user.email, subject: "You're invited to #{@user.organization.name}")
  end
end
