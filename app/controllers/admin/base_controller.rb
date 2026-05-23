module Admin
  class BaseController < ApplicationController
    before_action :authenticate!
    before_action :authorize_manager!
  end
end
