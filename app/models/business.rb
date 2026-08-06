class Business < ApplicationRecord
  before_validation :normalize_subdomain
  before_validation :normalize_custom_domain
  before_validation :normalize_contact_email_fields
  before_validation :ensure_domain_verification_token
  before_save :update_domain_status_on_change
  after_create :ensure_tenant_site_directory

  has_many :page_views, dependent: :delete_all
  has_many :users, dependent: :destroy
  has_many :contact_messages, dependent: :nullify
  has_many :reviews, dependent: :nullify
  has_many :tenant_site_pages, dependent: :destroy
  has_many_attached :assets

  validates :name, presence: true
  validates :subdomain, presence: true, uniqueness: true, format: { with: /\A[a-z0-9](?:[a-z0-9\-]{1,61}[a-z0-9])?\z/i }
  validates :custom_domain, uniqueness: { case_sensitive: false }, allow_blank: true
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :image_url, length: { maximum: 2048 }, allow_blank: true
  validates :tenant_contact_sender_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :tenant_contact_recipient_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validate :validate_tenant_contact_email_config_completeness

  scope :work_active, -> { where(active: true) }

  enum custom_domain_status: {
    unverified: 'unverified',
    pending: 'pending',
    active: 'active',
    failed: 'failed'
  }

  def platform_host
    # Prefer configured website_url if present, else fall back to current production host.
    GeneralSetting.first_or_initialize.website_url.presence ||
      (Rails.application.routes.default_url_options[:host] || 'xboltmedia.com')
  end

  def platform_domain
    host = platform_host.to_s
    host = host.sub(%r{\Ahttps?://}i, '')
    host = host.split('/').first
    host
  end

  def full_subdomain
    "#{subdomain}.#{platform_domain}"
  end

  def tenant_contact_configured?
    tenant_contact_sender_email.present? &&
      tenant_contact_sender_password.present? &&
      tenant_contact_recipient_email.present?
  end

  def deployed_site?
    site_root = Rails.root.join('public', 'tenant_sites', subdomain.to_s, 'index.html')
    File.exist?(site_root)
  end

  def domain_verification_value
    return nil if domain_verification_token.blank?

    "xbolt-verification=#{domain_verification_token}"
  end

  def domain_verification_host
    return nil if custom_domain.blank?

    "_xbolt-verification.#{custom_domain}"
  end

  def verify_custom_domain!
    raise ArgumentError, 'Custom domain is not set.' if custom_domain.blank?
    raise ArgumentError, 'Domain verification token is missing.' if domain_verification_value.blank?

    check = DomainDnsService.txt_record_present?(domain_verification_host, domain_verification_value)
    if check[:ok]
      update!(custom_domain_status: 'active')
    else
      update!(custom_domain_status: 'failed')
    end

    check
  end

  private

  def ensure_tenant_site_directory
    dir = Rails.root.join('public', 'tenant_sites', subdomain.to_s)
    FileUtils.mkdir_p(dir)
  rescue StandardError
    # Best-effort; never block business creation
    nil
  end

  def normalize_subdomain
    return if subdomain.blank?
    self.subdomain = subdomain.to_s.strip.downcase.gsub(/[^a-z0-9\-]/, '-').gsub(/-+/, '-').gsub(/\A-|-?\z/, '')
  end

  def normalize_custom_domain
    return if custom_domain.blank?

    dom = custom_domain.to_s.strip.downcase
    dom = dom.sub(%r{\Ahttps?://}i, '')
    dom = dom.split('/').first.to_s
    dom = dom.delete_prefix('www.')
    dom = dom.delete_suffix('.')
    self.custom_domain = dom
  end

  def normalize_contact_email_fields
    self.tenant_contact_sender_email = tenant_contact_sender_email.to_s.strip.downcase.presence
    self.tenant_contact_recipient_email = tenant_contact_recipient_email.to_s.strip.downcase.presence
    self.tenant_contact_sender_password = tenant_contact_sender_password.to_s.strip.presence
  end

  def ensure_domain_verification_token
    self.domain_verification_token ||= SecureRandom.hex(16)
  end

  def update_domain_status_on_change
    return unless will_save_change_to_custom_domain?

    if custom_domain.blank?
      self.custom_domain_status = 'unverified'
    else
      self.custom_domain_status = 'pending'
    end
  end

  def validate_tenant_contact_email_config_completeness
    values = [
      tenant_contact_sender_email,
      tenant_contact_sender_password,
      tenant_contact_recipient_email
    ]
    return if values.all?(&:blank?)
    return if values.all?(&:present?)

    errors.add(:base, 'Tenant contact email config is incomplete. Please set sender email, app password, and recipient email.')
  end
end

