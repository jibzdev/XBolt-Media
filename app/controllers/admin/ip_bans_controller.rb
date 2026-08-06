class Admin::IpBansController < ApplicationController
  layout "adminpanel"
  before_action :require_full_admin
  before_action :set_banned_ip, only: [:destroy]

  def index
    @general_setting = GeneralSetting.first_or_initialize
    @banned_ip = BannedIp.new
    @banned_ips = BannedIp.includes(:banned_by).order(created_at: :desc).page(params[:page]).per(30)
  end

  def create
    @banned_ip = BannedIp.new(banned_ip_params)
    @banned_ip.banned_by = current_user

    if @banned_ip.save
      Activity.log(current_user, "Banned IP #{@banned_ip.ip_address}")
      redirect_to admin_ip_bans_path, notice: "IP #{@banned_ip.ip_address} has been banned."
    else
      @general_setting = GeneralSetting.first_or_initialize
      @banned_ips = BannedIp.includes(:banned_by).order(created_at: :desc).page(params[:page]).per(30)
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    ip = @banned_ip.ip_address
    @banned_ip.destroy
    Activity.log(current_user, "Removed IP ban #{ip}")
    redirect_to admin_ip_bans_path, notice: "IP #{ip} has been unbanned."
  end

  private

  def set_banned_ip
    @banned_ip = BannedIp.find(params[:id])
  end

  def banned_ip_params
    params.require(:banned_ip).permit(:ip_address, :reason)
  end
end
