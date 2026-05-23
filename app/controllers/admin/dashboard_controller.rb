module Admin
  class DashboardController < BaseController
    def index
      @customers_count = current_organization.users.customer.count
      @staff_count = current_organization.users.staff.count
      @locations = current_organization.locations.active
      @open_requests = Request.joins(:location).where(locations: { organization_id: current_organization.id }).open.count
      @today_requests = Request.joins(:location)
        .where(locations: { organization_id: current_organization.id })
        .where(scheduled_for: Time.current.beginning_of_day..Time.current.end_of_day).count
    end
  end
end
