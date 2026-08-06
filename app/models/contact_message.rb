class ContactMessage < ApplicationRecord
  RATE_LIMIT_WINDOW = 15.minutes

  # Spam submissions are blocked, but no longer automatically ban the IP.
  SPAM_ATTEMPT_WINDOW = 1.hour

  # Submissions faster than this after the form rendered are almost always bots.
  MIN_FORM_FILL_SECONDS = 2
  MAX_FORM_AGE_SECONDS = 6.hours.to_i

  SYSTEM_SENDER_NAME = 'Security Monitor'.freeze
  SYSTEM_SENDER_EMAIL = 'security@xboltmedia.local'.freeze

  SPAM_PATTERNS = [
    /new messages from/i,
    /\bview:\s*https?:\/\//i,
    /\bwhatsapp\b/i,
    /🔥|🔔/,
    /\bbonus\b|\bcasino\b|\bcrypto\b/i,
    /\btelegram\b|\bforex\b|\binvestment opportunity\b/i,
    /\bseo\b\s+(services|expert|specialist|agency)/i,
    /(viagra|cialis|porn|sex chat)/i,
    /\b(buy|cheap)\s+(followers|likes|subscribers)\b/i
  ].freeze

  URL_PATTERN = %r{(?:https?://|www\.|[a-z0-9\-]+\.(?:com|net|org|info|biz|xyz|top|click|shop|online)\b)}i

  # Used as a hard spam signal and a UA signature.
  BOT_UA_PATTERNS = [
    /curl\//i,
    /wget/i,
    /python-requests/i,
    /python-urllib/i,
    /scrapy/i,
    /go-http-client/i,
    /httpie/i,
    /libwww-perl/i,
    /java\//i,
    /headlesschrome/i,
    /phantomjs/i,
    /node-fetch/i,
    /axios\//i,
    /okhttp\//i
  ].freeze

  # Search-engine and link-preview crawlers that should be allowed to browse the
  # site, but should never be hitting the contact form. If we see them on a
  # form submit, treat as obvious abuse.
  GOOD_BOT_UA_PATTERNS = [
    /googlebot/i,
    /bingbot/i,
    /duckduckbot/i,
    /slurp/i,
    /yandex(bot)?/i,
    /baiduspider/i,
    /applebot/i,
    /facebookexternalhit/i,
    /twitterbot/i,
    /linkedinbot/i,
    /telegrambot/i,
    /discordbot/i
  ].freeze

  belongs_to :business, optional: true

  validates :name, :email, :message, :ip_address, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, length: { maximum: 120 }
  validates :phone, length: { maximum: 40 }, allow_blank: true
  validates :message, length: { minimum: 5, maximum: 5000 }
  validate :not_known_spam

  scope :recent, -> { order(created_at: :desc) }
  scope :unread, -> { where(read_at: nil) }
  scope :system_messages, -> { where(name: SYSTEM_SENDER_NAME, email: SYSTEM_SENDER_EMAIL) }
  scope :user_messages, -> { where.not(name: SYSTEM_SENDER_NAME).or(where.not(email: SYSTEM_SENDER_EMAIL)) }

  def self.visible_to(user)
    return all if user&.full_admin?

    user_messages
  end

  def system?
    name == SYSTEM_SENDER_NAME && email == SYSTEM_SENDER_EMAIL
  end

  def read?
    read_at.present?
  end

  def mark_as_read!
    return if read?

    update!(read_at: Time.current)
  end

  def self.rate_limited?(ip, business: nil)
    scope = where(ip_address: ip.to_s).where('created_at > ?', RATE_LIMIT_WINDOW.ago)
    scope = scope.where(business: business) if business.present?
    scope.exists?
  end

  # Returns a hash describing how spammy a submission looks.
  # { score: Integer, reasons: [String], hard_block: Boolean }
  #
  # The old API returned a single reason string; spam_reason_for is preserved
  # as a thin shim for backwards compatibility.
  def self.assess_spam(name:, email:, phone:, message:, honeypot: nil, user_agent: nil, form_age_seconds: nil)
    score = 0
    reasons = []
    hard_block = false

    if honeypot.to_s.strip.present?
      score += 100
      reasons << 'honeypot_filled'
      hard_block = true
    end

    ua = user_agent.to_s
    if ua.blank?
      score += 60
      reasons << 'empty_user_agent'
    elsif BOT_UA_PATTERNS.any? { |p| ua.match?(p) }
      score += 100
      reasons << 'bot_user_agent'
      hard_block = true
    elsif GOOD_BOT_UA_PATTERNS.any? { |p| ua.match?(p) }
      # Search crawlers should not be POSTing forms.
      score += 100
      reasons << 'crawler_submitting_form'
      hard_block = true
    end

    if form_age_seconds.is_a?(Numeric)
      if form_age_seconds < MIN_FORM_FILL_SECONDS
        score += 70
        reasons << "submitted_too_fast(#{form_age_seconds}s)"
      elsif form_age_seconds > MAX_FORM_AGE_SECONDS
        score += 30
        reasons << 'stale_form_token'
      end
    end

    clean_name = name.to_s.strip
    clean_email = email.to_s.strip.downcase
    clean_phone = phone.to_s.strip
    clean_message = message.to_s.strip
    combined = "#{clean_name} #{clean_email} #{clean_message}".downcase

    if clean_name.length > 120
      score += 60
      reasons << 'name_too_long'
    end

    if clean_message.length < 8
      score += 50
      reasons << 'message_too_short'
    end

    if clean_phone.gsub(/\D/, '').length > 18
      score += 30
      reasons << 'phone_too_long'
    end

    url_count = combined.scan(URL_PATTERN).size
    if url_count == 1
      score += 15
      reasons << 'single_url'
    elsif url_count > 1
      score += 50
      reasons << "too_many_urls(#{url_count})"
    end

    pattern_hits = SPAM_PATTERNS.count { |pattern| combined.match?(pattern) }
    if pattern_hits.positive?
      score += [pattern_hits * 40, 80].min
      reasons << "pattern_hits(#{pattern_hits})"
    end

    if clean_name.present? && !clean_name.include?(' ') && clean_name.length >= 25
      score += 20
      reasons << 'long_unspaced_name'
    end

    if clean_name.present? && clean_email.present? && clean_name.downcase == clean_email
      score += 20
      reasons << 'name_matches_email'
    end

    score = 100 if hard_block && score < 100

    { score: score, reasons: reasons, hard_block: hard_block }
  end

  # Backwards-compatible boolean-style accessor used by older controllers.
  # Returns nil for clean submissions, otherwise a comma-joined reason string.
  def self.spam_reason_for(name:, email:, phone:, message:, honeypot: nil, user_agent: nil, form_age_seconds: nil)
    assessment = assess_spam(
      name: name, email: email, phone: phone, message: message,
      honeypot: honeypot, user_agent: user_agent, form_age_seconds: form_age_seconds
    )
    return nil if assessment[:score] < 50

    assessment[:reasons].join(',')
  end

  # Kept for existing controller call sites. Spam submissions are still counted
  # briefly for observability, but this no longer creates IP bans.
  def self.track_spam_attempt_and_auto_ban!(ip:, reason: nil, source:, score: 0, hard_block: false)
    normalized_ip = BannedIp.normalize_ip(ip)
    return false if normalized_ip.blank?
    return false if local_or_private_ip?(normalized_ip)

    weight = score.to_i
    weight = 30 if weight < 30 # any reported spam attempt counts at least this much

    bucket_key = spam_attempt_bucket_key(normalized_ip)
    unless Rails.cache.increment(bucket_key, weight, expires_in: SPAM_ATTEMPT_WINDOW)
      Rails.cache.write(bucket_key, weight, expires_in: SPAM_ATTEMPT_WINDOW)
    end

    Rails.logger.warn(
      "Spam submission blocked without IP ban: source=#{source} score=#{score} hard_block=#{hard_block} reason=#{reason} ip=#{normalized_ip}"
    )
    false
  rescue StandardError => e
    Rails.logger.error("Failed to track spam attempt for IP #{normalized_ip || ip}: #{e.class}: #{e.message}")
    false
  end

  def self.reset_spam_attempt_counter!(ip)
    normalized_ip = BannedIp.normalize_ip(ip)
    return if normalized_ip.blank?

    Rails.cache.delete(spam_attempt_bucket_key(normalized_ip))
  rescue StandardError
    nil
  end

  def self.spam_attempt_bucket_key(ip)
    "contact_spam_score:#{ip}"
  end

  def self.local_or_private_ip?(ip)
    ip_addr = IPAddr.new(ip)
    ip_addr.loopback? || ip_addr.private? || ip_addr.link_local?
  rescue IPAddr::InvalidAddressError
    false
  end

  private

  def not_known_spam
    assessment = self.class.assess_spam(
      name: name, email: email, phone: phone, message: message, user_agent: user_agent
    )
    return if assessment[:score] < 50

    errors.add(:base, 'Message looks like spam and was blocked.')
  end
end
