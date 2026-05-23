module Admin
  class RequestTypesController < BaseController
    before_action :set_type, only: [:edit, :update, :destroy, :reorder]

    def index
      @types = current_organization.request_types.ordered
    end

    def new
      @type = current_organization.request_types.new(
        applicable_storage_types: %w[dry in_water],
        color: "#2563eb",
        sort_order: (current_organization.request_types.maximum(:sort_order) || 0) + 10
      )
    end

    def create
      @type = current_organization.request_types.new(type_params)
      if @type.save
        redirect_to admin_request_types_path, notice: "Request type created"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @type.update(type_params)
        redirect_to admin_request_types_path, notice: "Request type updated"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @type.requests.exists?
        @type.update(is_active: false)
        redirect_to admin_request_types_path, notice: "Type has existing requests — deactivated instead of deleted"
      else
        @type.destroy
        redirect_to admin_request_types_path, notice: "Request type removed"
      end
    end

    def reorder
      direction = params[:direction].to_s
      others = current_organization.request_types.ordered.where.not(id: @type.id)
      delta = (direction == "up" ? -15 : 15)
      @type.update(sort_order: @type.sort_order + delta)
      current_organization.request_types.ordered.each_with_index do |t, i|
        t.update_column(:sort_order, (i + 1) * 10)
      end
      redirect_to admin_request_types_path
    end

    private

    def set_type
      @type = current_organization.request_types.find(params[:id])
    end

    def type_params
      raw = params.require(:request_type).permit(:name, :slug, :description, :requires_description,
                                                  :icon, :color, :sort_order, :is_active,
                                                  applicable_storage_types: [])
      raw[:applicable_storage_types] = Array(raw[:applicable_storage_types]).reject(&:blank?)
      raw
    end
  end
end
