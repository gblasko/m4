class NotificationMailer < ApplicationMailer
  def event_email
    @user = params[:user]
    @request = params[:request]
    @event = params[:event]
    @subject = subject_for(@event, @request)
    mail(to: @user.email, subject: @subject)
  end

  private

  def subject_for(event, request)
    type_name = request&.request_type&.name || "Request"
    boat = request&.boat&.name || ""
    case event
    when "request_submitted" then "Request received — #{type_name} for #{boat}"
    when "request_started"   then "Started — #{type_name} for #{boat}"
    when "request_completed" then "Completed — #{type_name} for #{boat}"
    when "request_cancelled" then "Cancelled — #{type_name} for #{boat}"
    when "public_note_added" then "Update on your #{type_name} request"
    when "request_assigned"  then "Assigned — #{type_name} for #{boat}"
    else "Marina update"
    end
  end
end
