class Admin::AccountController < ApplicationController
  layout 'adminpanel'
  before_action :require_login

  def edit_password
    @general_setting = GeneralSetting.first_or_initialize
  end

  def update_password
    @general_setting = GeneralSetting.first_or_initialize
    user = current_user

    current_password = params[:current_password].to_s
    new_password = params[:password].to_s
    confirmation = params[:password_confirmation].to_s

    unless user&.authenticate(current_password)
      flash.now[:alert] = 'Current password is incorrect.'
      return render :edit_password, status: :unprocessable_entity
    end

    if new_password.blank?
      flash.now[:alert] = 'New password cannot be blank.'
      return render :edit_password, status: :unprocessable_entity
    end

    if new_password != confirmation
      flash.now[:alert] = 'New password and confirmation do not match.'
      return render :edit_password, status: :unprocessable_entity
    end

    if user.update(password: new_password, password_confirmation: confirmation)
      redirect_to password_admin_account_path, notice: 'Password updated successfully.'
    else
      flash.now[:alert] = user.errors.full_messages.first || 'Could not update password.'
      render :edit_password, status: :unprocessable_entity
    end
  end
end
