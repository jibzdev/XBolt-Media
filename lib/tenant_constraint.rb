class TenantConstraint
  RESERVED_SUBDOMAINS = %w[www].freeze

  def matches?(request)
    host = request.host.to_s.downcase.delete_suffix('.')
    return false if host.blank?
    # In development we often use hosts like tenant.localhost or tenant.lvh.me.
    # Don't block tenant routing for those.
    return false if Rails.env.production? && host.include?('localhost')
    return false if host.match?(/\A\d{1,3}(\.\d{1,3}){3}\z/) # IP address

    # Custom domain match (exact, with optional www alias).
    custom_domain_candidates = [host]
    if host.start_with?('www.')
      bare_host = host.delete_prefix('www.')
      custom_domain_candidates << bare_host if bare_host.present?
    else
      custom_domain_candidates << "www.#{host}"
    end
    return true if Business.where(custom_domain_status: 'active').where('lower(custom_domain) IN (?)', custom_domain_candidates.uniq).exists?

    # Never resolve arbitrary external hosts by subdomain; that can leak a tenant
    # site onto the wrong domain. Subdomain routing is only valid on platform/dev hosts.
    return false unless eligible_for_subdomain_lookup?(request, host)

    # Subdomain match
    sub = extract_subdomain(request, host)
    return false if sub.blank? || RESERVED_SUBDOMAINS.include?(sub)
    Business.where(subdomain: sub).exists?
  rescue StandardError
    false
  end

  private

  def eligible_for_subdomain_lookup?(request, host)
    return true if host.end_with?('.localhost') || host.end_with?('.lvh.me')

    platform_host = platform_host_for(request)
    return false if platform_host.blank?

    host == platform_host || host.end_with?(".#{platform_host}")
  end

  def platform_host_for(request)
    configured = GeneralSetting.first_or_initialize.website_url.presence
    fallback = request.base_url
    candidate = configured.presence || fallback

    candidate.to_s
             .sub(%r{\Ahttps?://}i, '')
             .split('/')
             .first
             .to_s
             .split(':')
             .first
             .downcase
             .delete_suffix('.')
  rescue StandardError
    nil
  end

  # Rails won't always parse subdomains correctly for localhost-ish hosts.
  def extract_subdomain(request, host)
    sub = request.subdomains.first.to_s.downcase
    return sub if sub.present?

    # Support foo.localhost and foo.lvh.me in development
    if host.end_with?('.localhost')
      return host.split('.').first.to_s.downcase
    end

    if host.end_with?('.lvh.me')
      return host.split('.').first.to_s.downcase
    end

    nil
  end
end

