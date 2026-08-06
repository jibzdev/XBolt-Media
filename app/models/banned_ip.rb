class BannedIp < ApplicationRecord
  belongs_to :banned_by, class_name: "User", optional: true

  validates :ip_address, presence: true, uniqueness: { case_sensitive: false }
  validate :ip_address_must_be_valid

  before_validation :normalize_ip_address

  def self.normalize_ip(value)
    raw = value.to_s.strip
    return "" if raw.blank?

    IPAddr.new(raw).to_s
  rescue IPAddr::InvalidAddressError
    raw
  end

  private

  def normalize_ip_address
    self.ip_address = self.class.normalize_ip(ip_address)
  end

  def ip_address_must_be_valid
    return if ip_address.blank?

    IPAddr.new(ip_address)
  rescue IPAddr::InvalidAddressError
    errors.add(:ip_address, "must be a valid IPv4 or IPv6 address")
  end
end
