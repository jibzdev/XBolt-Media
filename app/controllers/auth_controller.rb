class AuthController < ApplicationController
  LOGIN_MAX_ATTEMPTS = 8
  LOGIN_THROTTLE_WINDOW = 15.minutes
  FORGOT_PASSWORD_MAX_ATTEMPTS = 5
  FORGOT_PASSWORD_THROTTLE_WINDOW = 15.minutes

  before_action :check_maintenance_mode, only: [:login_handle]

  def login
    @login_seo = SeoSetting.find_by(page_name: 'login')
    @general_setting = GeneralSetting.first_or_initialize
    if user_signed_in?
      redirect_to after_login_path_for(current_user)
    end
  end

  def login_handle
    @general_setting = GeneralSetting.first_or_initialize
    username = normalized_username_param

    if login_throttled?
      redirect_to login_path, alert: 'Too many login attempts. Please wait a few minutes and try again.'
      return
    end

    user = User.find_by(username: username)

    if user&.authenticate(params[:password].to_s)
      clear_login_throttle!(username)
      if @general_setting.maintenance_mode && !user.staff_admin?
        flash[:alert] = 'Logins are currently disabled due to maintenance.'
        redirect_to root_path
      else
        complete_login(user)
      end
    else
      record_login_failure!(username)
      redirect_to login_path, alert: 'Invalid username or password.'
    end
  end

  def forgot_password
    @forgot_password_seo = SeoSetting.find_by(page_name: 'forgot_password')
    @general_setting = GeneralSetting.first_or_initialize
  end

  def forgot_password_handle
    username = normalized_username_param

    if forgot_password_throttled?
      redirect_to forgot_password_path, alert: 'Too many password reset requests. Please wait before trying again.'
      return
    end

    user = User.find_by(username: username)
    begin
      if user&.email.present?
        user.generate_password_token!
        if defined?(UserMailer) && ActionMailer::Base.delivery_method != :test
          UserMailer.forgot_password(user).deliver_now
        end
      end
    rescue => e
      Rails.logger.error "Failed to process forgot password request: #{e.message}"
    ensure
      record_forgot_password_request!(username)
    end

    redirect_to forgot_password_sent_path, notice: 'If that account exists, a password reset link has been sent.'
  end

  def forgot_password_sent
    @general_setting = GeneralSetting.first_or_initialize
    unless flash[:notice]
      redirect_to forgot_password_path
    end
  end

  def edit_reset_password
    @general_setting = GeneralSetting.first_or_initialize
    @token = params[:token]
    user = User.find_by(reset_password_token: @token)

    if user&.password_token_valid?
      render :reset_password
    else
      redirect_to forgot_password_path, alert: 'Link has expired or is invalid.'
    end
  end

  def update_reset_password
    @token = params[:token]
    @user = User.find_by(reset_password_token: @token)

    if @user&.password_token_valid?
      if params[:password] != params[:password_confirmation]
        return redirect_to edit_reset_password_path(token: @token), alert: 'Passwords do not match'
      end

      if @user.reset_password!(params[:password])
        log_activity('User reset password')
        redirect_to login_path, notice: 'Password has been reset successfully.'
      else
        redirect_to edit_reset_password_path(token: @token), alert: @user.errors.full_messages.join(', ')
      end
    else
      redirect_to forgot_password_path, alert: 'Link has expired or is invalid.'
    end
  rescue => e
    Rails.logger.error "Error in update_reset_password: #{e.message}"
    redirect_to edit_reset_password_path(token: @token), alert: 'An error occurred while resetting your password. Please try again.'
  end

  def logout
    user = current_user
    log_activity('User logged out', user: user) if user
    reset_session
    redirect_to root_path, notice: 'Logged out successfully.'
  end

  def stop_impersonating
    impersonator = current_impersonator
    unless impersonator&.super_admin?
      reset_session
      redirect_to login_path, alert: 'Impersonation session expired. Please log in again.'
      return
    end

    impersonated_username = current_user&.username
    session[:user_id] = impersonator.id
    session.delete(:impersonator_user_id)
    @current_user = impersonator
    @current_impersonator = nil
    log_activity("Stopped impersonating #{impersonated_username}") if impersonated_username.present?
    redirect_to admin_users_path, notice: 'Returned to your Super Admin session.'
  end

  def verify_email
    user = User.find_by(verification_token: params[:token])
    if user&.verification_token_valid?
      user.verify_email!
      redirect_to after_login_path_for(user), notice: 'Email verified successfully.'
      
      # Send welcome email with error handling
      begin
        if defined?(UserMailer) && ActionMailer::Base.delivery_method != :test
          UserMailer.welcome_email(user).deliver_now
        end
      rescue => e
        Rails.logger.error "Failed to send welcome email: #{e.message}"
        # Don't fail the verification process if email fails
      end
    else
      redirect_to root_path, alert: 'Verification link has expired or is invalid.'
    end
  end

  def verify_email_page
    @user = current_user
    
    # Redirect to login if user is not authenticated
    unless @user
      redirect_to login_path, alert: 'Please log in to verify your email.'
      return
    end
    
    # Redirect to dashboard if user is already verified
    redirect_to after_login_path_for(@user) if @user.status == 'verified'
  end

  def resend_verification_email
    user = current_user

    if user.verification_token_valid?
      if user.verification_sent_at && Time.current < user.verification_sent_at + 2.minutes
        time_left = ((user.verification_sent_at + 2.minutes) - Time.current).to_i
        redirect_to verify_email_page_path, alert: "Please wait #{time_left} seconds before resending the verification email."
      else
        user.generate_verification_token!
        user.update(verification_sent_at: Time.current)
        
        # Send verification email with error handling
        begin
          if defined?(UserMailer) && ActionMailer::Base.delivery_method != :test
            UserMailer.verification_email(user).deliver_now
          end
        rescue => e
          Rails.logger.error "Failed to send verification email: #{e.message}"
          # Continue with the process even if email fails
        end
        
        redirect_to verify_email_page_path, notice: 'Verification email sent successfully. Please check your inbox.'
      end
    else
      user.generate_verification_token!
      user.update(verification_sent_at: Time.current)
      
      # Send verification email with error handling
      begin
        if defined?(UserMailer) && ActionMailer::Base.delivery_method != :test
          UserMailer.verification_email(user).deliver_now
        end
      rescue => e
        Rails.logger.error "Failed to send verification email: #{e.message}"
        # Continue with the process even if email fails
      end
      
      redirect_to verify_email_page_path, notice: 'Verification email sent successfully. Please check your inbox.'
    end
  rescue => e
    Rails.logger.error "Error in resend_verification_email: #{e.message}"
    redirect_to verify_email_page_path, alert: 'An error occurred while resending the verification email.'
  end

  private

  def complete_login(user)
    # Prevent session fixation by rotating the session before auth.
    reset_session
    user.update_columns(inactive: false, last_active_at: Time.current)
    session[:user_id] = user.id
    @current_user = user
    log_activity('User logged in', user: user)
    log_ip_activity(user: user)

    redirect_to after_login_path_for(user), notice: 'Login successful. Welcome back!'
  end

  def after_login_path_for(user)
    admin_dashboard_path
  end

  def normalized_username_param
    params[:username].to_s.strip
  end

  def request_ip
    request.remote_ip.to_s
  end

  def throttle_key(scope, identifier)
    "auth:throttle:#{scope}:#{identifier}"
  end

  def blocked_key(scope, identifier)
    "auth:throttle:block:#{scope}:#{identifier}"
  end

  def blocked?(scope, identifier)
    blocked_until = Rails.cache.read(blocked_key(scope, identifier))
    blocked_until.present? && blocked_until > Time.current
  end

  def increment_attempts!(scope, identifier, window, max_attempts)
    attempts_key = throttle_key(scope, identifier)
    attempts = Rails.cache.read(attempts_key).to_i + 1
    Rails.cache.write(attempts_key, attempts, expires_in: window)
    if attempts >= max_attempts
      Rails.cache.write(blocked_key(scope, identifier), Time.current + window, expires_in: window)
    end
  end

  def clear_throttle!(scope, identifier)
    Rails.cache.delete(throttle_key(scope, identifier))
    Rails.cache.delete(blocked_key(scope, identifier))
  end

  def login_throttled?
    blocked?(:login_ip, request_ip) || blocked?(:login_user, normalized_username_param.presence || 'unknown')
  end

  def record_login_failure!(username)
    identity = username.presence || 'unknown'
    increment_attempts!(:login_ip, request_ip, LOGIN_THROTTLE_WINDOW, LOGIN_MAX_ATTEMPTS)
    increment_attempts!(:login_user, identity, LOGIN_THROTTLE_WINDOW, LOGIN_MAX_ATTEMPTS)
  end

  def clear_login_throttle!(username)
    identity = username.presence || 'unknown'
    clear_throttle!(:login_ip, request_ip)
    clear_throttle!(:login_user, identity)
  end

  def forgot_password_throttled?
    blocked?(:forgot_password_ip, request_ip) || blocked?(:forgot_password_user, normalized_username_param.presence || 'unknown')
  end

  def record_forgot_password_request!(username)
    identity = username.presence || 'unknown'
    increment_attempts!(:forgot_password_ip, request_ip, FORGOT_PASSWORD_THROTTLE_WINDOW, FORGOT_PASSWORD_MAX_ATTEMPTS)
    increment_attempts!(:forgot_password_user, identity, FORGOT_PASSWORD_THROTTLE_WINDOW, FORGOT_PASSWORD_MAX_ATTEMPTS)
  end
end
