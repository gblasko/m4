module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_user || reject_unauthorized_connection
    end

    private

    def find_user
      raw = cookies.encrypted[:marina_session]
      Session.find_active(raw)&.user
    end
  end
end
