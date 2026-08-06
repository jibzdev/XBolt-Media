class LandingController < ApplicationController
  layout false

  def index
    @general_setting = GeneralSetting.first_or_initialize
    @landing_seo = SeoSetting.for_page('landing')
    @launches_count = Business.count
    @reviews = Review.visible.limit(12)
  end

  def about
    @general_setting = GeneralSetting.first_or_initialize
    @about_seo = SeoSetting.find_by(page_name: 'about')
  end

  def services
    @general_setting = GeneralSetting.first_or_initialize
    @services = Service.active.ordered
  end

  def work
    @general_setting = GeneralSetting.first_or_initialize
    @tenant_businesses = Business.work_active.order(created_at: :desc)
    @work_cards = WorkCard.visible
  end

  def reviews
    @general_setting = GeneralSetting.first_or_initialize
    @reviews_seo = SeoSetting.for_page('reviews')
    @reviews = Review.visible
    @average_rating = @reviews.average_rating
  end

  def contact
    @general_setting = GeneralSetting.first_or_initialize
    @contact_seo = SeoSetting.find_by(page_name: 'contact')
  end

  def contact_submit
    contact = contact_params

    if contact[:name].blank? || contact[:email].blank? || contact[:message].blank?
      flash[:alert] = "Please fill in your name, email, and message."
      return redirect_to contact_path
    end

    ip = request.remote_ip.to_s
    assessment = ContactMessage.assess_spam(
      name: contact[:name],
      email: contact[:email],
      phone: contact[:phone],
      message: contact[:message],
      honeypot: contact[:website],
      user_agent: request.user_agent.to_s,
      form_age_seconds: form_age_seconds_from(contact[:form_t])
    )
    if assessment[:score] >= 50
      ContactMessage.track_spam_attempt_and_auto_ban!(
        ip: ip,
        reason: assessment[:reasons].join(','),
        source: 'host_contact',
        score: assessment[:score],
        hard_block: assessment[:hard_block]
      )
      Rails.logger.warn("Host contact spam blocked: score=#{assessment[:score]} reasons=#{assessment[:reasons].join(',')} ip=#{ip}")
      flash[:notice] = 'Thanks! Your message has been received.'
      return redirect_to contact_path
    end

    if ContactMessage.rate_limited?(ip)
      flash[:alert] = "You've already sent a message recently. Please wait 15 minutes before sending another."
      return redirect_to contact_path
    end

    message = ContactMessage.new(
      name: contact[:name].to_s.strip,
      email: contact[:email].to_s.strip,
      phone: contact[:phone].to_s.strip.presence,
      message: contact[:message].to_s.strip,
      ip_address: ip,
      user_agent: request.user_agent.to_s
    )

    if message.save
      ContactMessage.reset_spam_attempt_counter!(ip)
      flash[:notice] = "Thanks! Your message has been sent."
    else
      flash[:alert] = message.errors.full_messages.first || "Sorry — we couldn't send your message right now. Please try again later."
    end

    redirect_to contact_path
  end

  def terms_of_service
    @general_setting = GeneralSetting.first_or_initialize
    @seo_setting = SeoSetting.for_page('terms_of_service')
  end

  def privacy_policy
    @general_setting = GeneralSetting.first_or_initialize
    @seo_setting = SeoSetting.for_page('privacy_policy')
  end

  private

  def contact_params
    params.permit(:name, :email, :phone, :message, :website, :form_t).to_h.symbolize_keys
  end

  def form_age_seconds_from(token)
    rendered_at = token.to_i
    return nil if rendered_at <= 0

    age = Time.current.to_i - rendered_at
    age.negative? ? nil : age
  end
end
