class User < ApplicationRecord
  ADMIN_ROLES = %w[moderator admin super_admin].freeze

  has_secure_password
  belongs_to :business, optional: true

  acts_as_google_authenticated lookup_token: :google_secret,
                              encrypt_secrets: true,
                              drift: 30

  has_many :ip_logs, dependent: :destroy
  has_many :activities, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :notifications, dependent: :destroy
  has_many :banned_ips, foreign_key: :banned_by_id, dependent: :nullify, inverse_of: :banned_by

  # Username-based authentication (email optional).
  validates :email, uniqueness: true, allow_blank: true, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :username, presence: true, uniqueness: true
  validates :first_name, length: { minimum: 2, maximum: 50 }, format: { with: /\A[a-zA-Z\s\-']+\z/, message: "can only contain letters, spaces, hyphens, and apostrophes" }, allow_blank: true
  validates :last_name, length: { minimum: 2, maximum: 50 }, format: { with: /\A[a-zA-Z\s\-']+\z/, message: "can only contain letters, spaces, hyphens, and apostrophes" }, allow_blank: true
  validates :phone_number, format: { with: /\A[\+]?[1-9][\d]{0,15}\z/, message: "must be a valid phone number" }, allow_blank: true
  validates :admin_role, inclusion: { in: ADMIN_ROLES }, allow_blank: true

  # Custom validations for profile completion
  validate :validate_profile_completion, if: :profile_completion_context?
  before_validation :normalize_admin_role
  before_save :sync_admin_flag_from_role

  def profile_completion_context?
    @profile_completion_context == true
  end

  def profile_completion_context=(value)
    @profile_completion_context = value
  end

  def full_name
    if first_name.present? && last_name.present?
      "#{first_name} #{last_name}"
    else
      username
    end
  end

  def display_name
    full_name
  end

  def initials
    if first_name.present? && last_name.present?
      "#{first_name.first.upcase}#{last_name.first.upcase}"
    else
      username.first(2).upcase
    end
  end

  def profile_completion_percentage
    required_fields = [:first_name, :last_name, :phone_number]
    completed_fields = required_fields.count { |field| send(field).present? }
    (completed_fields.to_f / required_fields.count * 100).round
  end

  def profile_complete?
    first_name.present? && last_name.present? && phone_number.present?
  end

  def generate_verification_token!
    self.verification_token = generate_token
    self.verification_sent_at = Time.now.utc
    save!
  end

  def generate_password_token!
    self.reset_password_token = generate_token
    self.reset_password_sent_at = Time.now.utc
    save!
  end

  def password_token_valid?
    (self.reset_password_sent_at + 10.minutes) > Time.now.utc
  end

  def reset_password!(password)
    self.reset_password_token = nil
    self.password = password
    save!
  end

  def verification_token_valid?
    return false if verification_sent_at.nil?
    (self.verification_sent_at + 24.hours) > Time.now.utc
  end

  def verify_email!
    self.verification_token = nil
    self.status = "verified"
    save!
  end

  def admin?
    staff_admin?
  end

  def moderator?
    effective_admin_role == 'moderator'
  end

  def staff_admin?
    effective_admin_role.present?
  end

  def full_admin?
    effective_admin_role.in?(%w[admin super_admin])
  end

  def super_admin?
    effective_admin_role == 'super_admin'
  end

  def effective_admin_role
    admin_role.presence || (self[:admin] == true ? 'admin' : nil)
  end

  def admin_role_label
    case effective_admin_role
    when 'super_admin' then 'Super Admin'
    when 'admin' then 'Admin'
    when 'moderator' then 'Moderator'
    else 'Business'
    end
  end

  def active?
    status == "verified"
  end

  def inactive?
    inactive == true
  end

  def info_complete?
    profile_complete?
  end

  def can_be_deleted?
    # Check if user has any critical data that would prevent deletion
    return false if business_id.present?
    return false if staff_admin? && User.where(admin: true).count <= 1
    true
  end

  def safe_destroy
    return false unless can_be_deleted?
    
    transaction do
      cleanup_associations
      destroy!
    end
    true
  rescue => e
    Rails.logger.error("Safe destroy failed for user #{id}: #{e.message}")
    errors.add(:base, "Cannot delete user: #{e.message}")
    false
  end

  private

  def validate_profile_completion
    if first_name.blank?
      errors.add(:first_name, "can't be blank")
    end
    
    if last_name.blank?
      errors.add(:last_name, "can't be blank")
    end
    
    if phone_number.blank?
      errors.add(:phone_number, "can't be blank")
    end
  end

  def normalize_admin_role
    self.admin_role = admin_role.to_s.strip.presence
    self.admin_role = nil if admin_role.blank?
  end

  def sync_admin_flag_from_role
    if admin_role.present?
      self.admin = true
    elsif self[:admin] == true
      self.admin_role = 'admin'
    else
      self.admin = false
    end
  end

  before_save :update_last_active
  before_destroy :cleanup_associations

  def set_google_secret
    self.google_secret = ROTP::Base32.random
  end

  def google_qr_uri
    issuer = "XBolt"
    label = "#{email}"
    ROTP::TOTP.new(google_secret, issuer: issuer).provisioning_uri(label)
  end

  def google_authentic?(code)
    return false if google_secret.blank?
    ROTP::TOTP.new(google_secret).verify(code.to_s, drift_behind: 15, drift_ahead: 15)
  end

  private

  def generate_token
    SecureRandom.hex(10)
  end

  def update_last_active
    self.last_active_at = Time.current if self.changed?
  end

  def cleanup_associations
    # Safely destroy associations with error handling
    begin
      activities.destroy_all if activities.any?
    rescue => e
      Rails.logger.error("Failed to destroy activities for user #{id}: #{e.message}")
    end
    
    begin
      ip_logs.destroy_all if ip_logs.any?
    rescue => e
      Rails.logger.error("Failed to destroy ip_logs for user #{id}: #{e.message}")
    end
    
    begin
      notifications.destroy_all if notifications.any?
    rescue => e
      Rails.logger.error("Failed to destroy notifications for user #{id}: #{e.message}")
    end
    
    begin
      payments.destroy_all if payments.any?
    rescue => e
      Rails.logger.error("Failed to destroy payments for user #{id}: #{e.message}")
    end
  end
end
