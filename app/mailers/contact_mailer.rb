class ContactMailer < ApplicationMailer
  skip_before_action :set_anti_spam_headers, only: [:tenant_contact_notification, :tenant_contact_confirmation]

  def contact_message(name:, email:, phone: nil, message:)
    @name = name
    @email = email
    @phone = phone
    @message = message

    to_address = GeneralSetting.first_or_initialize.contact_email.presence || 'rkcustomsportsmouth@gmail.com'

    mail(
      to: to_address,
      reply_to: email,
      subject: "New contact form message from #{@name}"
    )
  end

  def tenant_contact_notification(business:, name:, email:, phone: nil, message:)
    @business = business
    @name = name
    @email = email
    @phone = phone
    @message = message

    msg = mail(
      to: @business.tenant_contact_recipient_email,
      from: "#{@business.name} <#{@business.tenant_contact_sender_email}>",
      reply_to: email,
      subject: "New contact form message for #{@business.name}"
    ) do |format|
      format.html { render layout: 'tenant_mailer' }
      format.text { render layout: 'tenant_mailer' }
    end

    msg.delivery_method(:smtp, tenant_delivery_options(@business))
    msg
  end

  def tenant_contact_confirmation(business:, name:, email:, message:)
    @business = business
    @name = name
    @email = email
    @message = message

    msg = mail(
      to: email,
      from: "#{@business.name} <#{@business.tenant_contact_sender_email}>",
      subject: "Thanks for contacting #{@business.name}"
    ) do |format|
      format.html { render layout: 'tenant_mailer' }
      format.text { render layout: 'tenant_mailer' }
    end

    msg.delivery_method(:smtp, tenant_delivery_options(@business))
    msg
  end

  private

  def tenant_delivery_options(business)
    {
      address: 'smtp.gmail.com',
      port: 587,
      user_name: business.tenant_contact_sender_email,
      password: business.tenant_contact_sender_password,
      authentication: 'plain',
      enable_starttls_auto: true
    }
  end
end

