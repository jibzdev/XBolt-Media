require 'resolv'

class DomainDnsService
  def self.lookup(domain)
    domain = domain.to_s.strip.downcase
    return { domain: domain, cnames: [], a_records: [], error: 'Domain is blank' } if domain.blank?

    cnames = []
    a_records = []

    Resolv::DNS.open do |dns|
      dns.getresources(domain, Resolv::DNS::Resource::IN::CNAME).each do |r|
        cnames << r.name.to_s.downcase
      end

      dns.getresources(domain, Resolv::DNS::Resource::IN::A).each do |r|
        a_records << r.address.to_s
      end
    end

    { domain: domain, cnames: cnames.uniq, a_records: a_records.uniq, error: nil }
  rescue StandardError => e
    { domain: domain, cnames: [], a_records: [], error: e.message }
  end

  def self.lookup_txt(domain)
    domain = domain.to_s.strip.downcase
    return { domain: domain, txt_records: [], error: 'Domain is blank' } if domain.blank?

    txt_records = []
    Resolv::DNS.open do |dns|
      dns.getresources(domain, Resolv::DNS::Resource::IN::TXT).each do |record|
        txt_records << record.strings.join
      end
    end

    { domain: domain, txt_records: txt_records.uniq, error: nil }
  rescue StandardError => e
    { domain: domain, txt_records: [], error: e.message }
  end

  def self.txt_record_present?(domain, expected_value)
    result = lookup_txt(domain)
    return { ok: false, result: result, reason: result[:error] } if result[:error].present?

    expected = expected_value.to_s.strip
    ok = result[:txt_records].any? { |value| value.to_s.strip == expected }

    { ok: ok, result: result, reason: ok ? nil : "Expected TXT value #{expected}" }
  end

  # Minimal “is it live?” check: does the domain CNAME to the tenant subdomain.
  # For apex domains, many DNS providers use ALIAS/ANAME (won’t show as CNAME),
  # so we only mark active when the expected CNAME is present.
  def self.points_to?(domain, expected_target)
    result = lookup(domain)
    return { ok: false, result: result, reason: result[:error] } if result[:error].present?

    expected = expected_target.to_s.strip.downcase.chomp('.')
    cnames = result[:cnames].map { |c| c.chomp('.') }
    ok = cnames.include?(expected)

    { ok: ok, result: result, reason: ok ? nil : "Expected CNAME to #{expected}" }
  end
end

