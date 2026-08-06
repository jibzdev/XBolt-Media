class Admin::UsersController < ApplicationController
  layout 'adminpanel'
  before_action -> { require_admin_area(:users) }
  before_action :require_full_admin, except: [:index, :show]
  before_action :set_user, only: [:show, :edit, :update, :destroy, :impersonate]

  def index
    @users = User.order(created_at: :desc)
    @users = @users.where(status: params[:status]) if params[:status].present?
    @users = @users.where(admin: params[:admin]) if params[:admin].present?
    @users = @users.page(params[:page]).per(20)
  end

  def show
    @general_setting = GeneralSetting.first_or_initialize
    @login_url = login_url
    @can_view_user_tracking = current_user&.full_admin?
    @recent_activities = Activity.where(user: @user).order(created_at: :desc).limit(@can_view_user_tracking ? 20 : 5)

    if @can_view_user_tracking
      @ip_logs = @user.ip_logs.order(login_time: :desc).limit(25)
      known_ips = @ip_logs.map(&:ip_address).compact_blank.uniq
      known_ip_hashes = known_ips.filter_map { |ip| RequestIp.hash_for(ip) }.uniq
      @recent_page_views = known_ip_hashes.any? ? PageView.where(ip_hash: known_ip_hashes).recent.limit(25) : PageView.none
      @tracking_summary = {
        activities: @user.activities.count,
        logins: @user.ip_logs.count,
        page_views: known_ip_hashes.any? ? PageView.where(ip_hash: known_ip_hashes).count : 0,
        unique_ips: known_ips.count
      }
    end

    creds = flash[:new_user_credentials]
    if creds.is_a?(Hash) && creds['user_id'].to_i == @user.id
      @new_user_credentials = creds
    end
  end

  def edit
    @general_setting = GeneralSetting.first_or_initialize
    @ip_logs = @user.ip_logs.order(login_time: :desc) || []
  end

  def new
    @general_setting = GeneralSetting.first_or_initialize
    @user = User.new(status: 'verified')
  end

  def create
    @general_setting = GeneralSetting.first_or_initialize
    attrs = user_params.to_h

    generated_password = nil
    if attrs['password'].blank?
      generated_password = SecureRandom.base58(14)
      attrs['password'] = generated_password
      attrs['password_confirmation'] = generated_password
    end

    @user = User.new(attrs)
    @user.status ||= 'verified'

    if @user.save
      log_activity("Created user #{@user.username}")
      password_for_display = generated_password || attrs['password']
      flash[:new_user_credentials] = {
        'user_id' => @user.id,
        'username' => @user.username,
        'password' => password_for_display,
        'login_url' => login_url
      }
      redirect_to admin_user_path(@user), notice: 'User created successfully!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @user.update(user_params)
      log_activity("Updated user #{@user.username}")
      redirect_to edit_admin_user_path(@user), notice: 'User updated successfully!'
    else
      @general_setting = GeneralSetting.first_or_initialize
      render :edit
    end
  end

  def destroy
    username = @user.username
    
    Rails.logger.info("Attempting to delete user: #{username} (ID: #{@user.id})")
    Rails.logger.info("Current user: #{current_user.username} (ID: #{current_user.id})")
    Rails.logger.info("User to delete role: #{@user.admin_role_label}")
    Rails.logger.info("Current user role: #{current_user.admin_role_label}")
    
    # Prevent admin from deleting themselves
    if @user == current_user
      Rails.logger.warn("Admin attempted to delete their own account")
      redirect_to admin_users_path, alert: 'You cannot delete your own account.'
      return
    end

    if @user.business.present?
      Rails.logger.warn("Admin attempted to delete tenant login user=#{@user.id} business=#{@user.business_id}")
      redirect_to admin_users_path, alert: 'This user is a tenant login and cannot be deleted here. Delete the business, or reset/regenerate the login from the tenant page.'
      return
    end
    
    # Only super admins can delete or demote other staff accounts.
    if @user.staff_admin? && !current_user.super_admin?
      Rails.logger.warn("Admin attempted to delete another staff user")
      redirect_to admin_users_path, alert: 'Only super admins can delete staff users.'
      return
    end
    
    # Check if user can be deleted
    unless @user.can_be_deleted?
      Rails.logger.warn("User #{username} cannot be deleted - validation failed")
      redirect_to admin_users_path, alert: 'This user cannot be deleted. They may be the last admin user.'
      return
    end
    
    begin
      Rails.logger.info("Proceeding with safe deletion of user #{username}")
      if @user.safe_destroy
        begin
          log_activity("Deleted user #{username}")
        rescue => e
          Rails.logger.error("Failed to log activity for user deletion: #{e.message}")
        end
        Rails.logger.info("Successfully deleted user #{username}")
        redirect_to admin_users_path, notice: 'User deleted successfully!'
      else
        error_messages = @user.errors.full_messages.join(', ')
        Rails.logger.error("Failed to delete user #{username}: #{error_messages}")
        redirect_to admin_users_path, alert: "Failed to delete user: #{error_messages}"
      end
    rescue => e
      Rails.logger.error("Exception while deleting user #{username}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      redirect_to admin_users_path, alert: "Error deleting user: #{e.message}"
    end
  end

  def impersonate
    unless current_user&.super_admin?
      redirect_to admin_user_path(@user), alert: 'Only super admins can log in as another user.'
      return
    end

    if @user == current_user
      redirect_to admin_user_path(@user), alert: 'You are already logged in as this user.'
      return
    end

    impersonator = current_impersonator || current_user
    session[:impersonator_user_id] = impersonator.id
    session[:user_id] = @user.id
    @current_user = @user
    @current_impersonator = impersonator
    Activity.log(impersonator, "Started impersonating #{@user.username}")

    redirect_to admin_dashboard_path, notice: "Logged in as #{@user.username}."
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    permitted = [:username, :email, :first_name, :last_name, :phone_number, :status, :password, :password_confirmation, :receive_email_notifications]
    permitted += [:admin, :admin_role] if current_user&.super_admin?
    attrs = params.require(:user).permit(permitted)
    if current_user&.super_admin? && attrs.key?(:admin_role)
      attrs[:admin] = attrs[:admin_role].present?
    end
    attrs.delete(:password) if attrs[:password].blank?
    attrs.delete(:password_confirmation) if attrs[:password_confirmation].blank?
    attrs
  end
end
