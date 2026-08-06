class RequestIp
  def self.client_ip(request)
    request.remote_ip.to_s
  end

  def self.hash_for(ip)
    normalized = BannedIp.normalize_ip(ip.to_s)
    return nil if normalized.blank?

    digest_input = "#{ip_hash_pepper}:#{normalized}"
    Digest::SHA256.hexdigest(digest_input)
  end

  def self.ip_hash_pepper
    ENV["IP_HASH_PEPPER"].presence || Rails.application.secret_key_base
  end
  private_class_method :ip_hash_pepper
end
