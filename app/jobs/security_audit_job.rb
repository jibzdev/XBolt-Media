class SecurityAuditJob < ApplicationJob
  queue_as :default

  SUSPICIOUS_PATH_LIKE_PATTERNS = [
    '%wp-admin%',
    '%wp-content/plugins%',
    '%wp_filemanager.php%',
    '%xmlrpc%',
    '%.env%',
    '%/.git%',
    '%/phpmyadmin%',
    '%/cgi-bin%',
    '%/HNAP1%',
    '%/boaform%',
    '%/setup.cgi%',
    '%/admin.php%',
    '%/login.php%',
    '%/index.php%'
  ].freeze
  REQUEST_BURST_THRESHOLD = 80

  def perform(window_end: Time.current)
    hour_key = window_end.beginning_of_hour.to_i
    dedupe_key = "security_audit:processed:#{hour_key}"
    return if Rails.cache.read(dedupe_key)

    window_start = window_end - 1.hour
    scope = PageView.where(occurred_at: window_start..window_end)

    suspicious_scope = build_suspicious_scope(scope)
    suspicious_count = suspicious_scope.count
    # Only generate an alert if suspicious paths were hit.
    return if suspicious_count.zero?

    burst_by_ip = scope.group(:ip_hash).having('COUNT(*) >= ?', REQUEST_BURST_THRESHOLD).order(Arel.sql('COUNT(*) DESC')).limit(10).count

    top_pages = suspicious_scope.group(:path).order(Arel.sql('COUNT(*) DESC')).limit(10).count
    top_hosts = suspicious_scope.group(:host).order(Arel.sql('COUNT(*) DESC')).limit(10).count
    top_suspicious_ips = suspicious_scope.group(:ip_hash).order(Arel.sql('COUNT(*) DESC')).limit(10).count

    lines = []
    lines << '[SECURITY ALERT] Suspicious traffic detected in the last hour'
    lines << "Window: #{window_start.utc.iso8601} to #{window_end.utc.iso8601}"
    lines << "Suspicious path hits: #{suspicious_count}"
    lines << "Request bursts: #{burst_by_ip.size}"
    lines << ''
    unless top_pages.blank?
      lines << 'Top suspicious pages:'
      top_pages.each { |path, count| lines << "- #{path}: #{count}" }
      lines << ''
    end
    unless top_suspicious_ips.blank?
      lines << 'Top suspicious IP hashes:'
      top_suspicious_ips.each { |ip_hash, count| lines << "- #{ip_hash}: #{count}" }
      lines << ''
    end
    unless burst_by_ip.blank?
      lines << "IPs with >=#{REQUEST_BURST_THRESHOLD} requests/hour:"
      burst_by_ip.each { |ip_hash, count| lines << "- #{ip_hash}: #{count}" }
      lines << ''
    end
    unless top_hosts.blank?
      lines << 'Affected hosts:'
      top_hosts.each { |host, count| lines << "- #{host}: #{count}" }
    end

    ContactMessage.create!(
      name: 'Security Monitor',
      email: 'security@xboltmedia.local',
      phone: nil,
      message: lines.join("\n"),
      ip_address: 'system',
      user_agent: 'SecurityAuditJob'
    )

    Rails.cache.write(dedupe_key, true, expires_in: 2.hours)
  rescue StandardError => e
    Rails.logger.error("SecurityAuditJob failed: #{e.class}: #{e.message}")
  end

  private

  def build_suspicious_scope(scope)
    conditions = SUSPICIOUS_PATH_LIKE_PATTERNS.map { 'LOWER(path) LIKE ?' }.join(' OR ')
    values = SUSPICIOUS_PATH_LIKE_PATTERNS.map(&:downcase)
    scope.where(conditions, *values)
  end
end
