class Admin::ServicesController < ApplicationController
  layout 'adminpanel'
  before_action -> { require_admin_area(:services) }
  before_action :set_service, only: [:edit, :update, :destroy]

  def index
    @services = Service.order(:position, :name)
    @services = @services.where(category: params[:category]) if params[:category].present?
    @services = @services.where(active: params[:active]) if params[:active].present?
  end

  # show removed per requirements

  def new
    @general_setting = GeneralSetting.first_or_initialize
    @service = Service.new
  end

  def create
    @general_setting = GeneralSetting.first_or_initialize
    @service = Service.new(service_params)
    
    if @service.save
      Activity.log(current_user, "Created new service: #{@service.name}")
      redirect_to admin_services_path, notice: 'Service created successfully!'
    else
      render :new
    end
  end

  def edit
    @general_setting = GeneralSetting.first_or_initialize
  end

  def update
    @general_setting = GeneralSetting.first_or_initialize
    if @service.update(service_params)
      Activity.log(current_user, "Updated service: #{@service.name}")
      redirect_to admin_services_path, notice: 'Service updated successfully!'
    else
      render :edit
    end
  end

  def destroy
    service_name = @service.name
    @service.destroy
    Activity.log(current_user, "Deleted service: #{service_name}")
    redirect_to admin_services_path, notice: 'Service deleted successfully!'
  end

  def reorder
    params[:service_ids].each_with_index do |id, index|
      Service.where(id: id).update_all(position: index + 1)
    end
    render json: { success: true }
  end

  # toggle_active removed per requirements

  private

  def set_service
    @service = Service.find(params[:id])
  end

  def service_params
    params.require(:service).permit(:name, :base_price, :category, :description, :active, :position)
  end
end
