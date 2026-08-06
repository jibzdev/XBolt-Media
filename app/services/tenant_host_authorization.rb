class TenantHostAuthorization
  CACHE_TTL = 5.minutes

  # Returns true when Host Authorization should be skipped for this request.
  # Platform hosts remain allowlisted via config.hosts; this covers verified
  # tenant custom domains and local/health-check addresses.
  def self.excluded?(request)
    host = request.host.to_s.downcase.delete_suffix(".")
    return true if host.blank?
    return true if local_or_healthcheck_host?(host)
    return true if verified_custom_domain?(host)

    false
  end

  def self.local_or_healthcheck_host?(host)
    host == "localhost" ||
      host.end_with?(".localhost") ||
      host.end_with?(".lvh.me") ||
      host.match?(/\A\d{1,3}(?:\.\d{1,3}){3}\z/)
  end

  def self.verified_custom_domain?(host)
    candidates = [host]
    candidates << host.delete_prefix("www.") if host.start_with?("www.")
    candidates << "www.#{host}" unless host.start_with?("www.")

    cache_key = "tenant_host_auth:#{candidates.sort.join('|')}"
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      Business.where(custom_domain_status: "active")
              .where("lower(custom_domain) IN (?)", candidates.uniq)
              .exists?
    end
  rescue StandardError => e
    Rails.logger.error("Tenant host authorization lookup failed: #{e.class}: #{e.message}")
    false
  end

  private_class_method :local_or_healthcheck_host?, :verified_custom_domain?
end
