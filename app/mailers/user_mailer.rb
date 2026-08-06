class UserMailer < ApplicationMailer
  default from: -> { GeneralSetting.first_or_initialize.contact_email || 'XBolt <rkcustomsportsmouth@gmail.com>' }
  default reply_to: -> { GeneralSetting.first_or_initialize.contact_email || 'XBolt <rkcustomsportsmouth@gmail.com>' }
  default 'Return-Path' => 'rkcustomsportsmouth@gmail.com'

  def welcome_email(user)
    @user = user
    @general_setting = GeneralSetting.first_or_initialize
    
    mail(
      to: @user.email,
      subject: "Welcome to XBolt!"
    )
  end

  def verification_email(user)
    @user = user
    @general_setting = GeneralSetting.first_or_initialize
    @url = verify_email_url(token: @user.verification_token)
    
    mail(
      to: @user.email,
      subject: "Verify Your Email - XBolt"
    )
  end

  def forgot_password(user)
    @user = user
    @general_setting = GeneralSetting.first_or_initialize
    
    mail(
      to: @user.email,
      subject: "Reset Your Password - XBolt"
    )
  end
end
