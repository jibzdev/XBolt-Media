require 'fileutils'

class TenantWatermarkInstaller
  SCRIPT_FILENAME = 'xbolt-watermark.js'.freeze
  MARKER = 'data-xbolt-watermark'.freeze
  BODY_CLOSE = %r{</body\s*>}i
  EXISTING_TAG = %r{<script[^>]*#{MARKER}[^>]*>\s*</script>}i

  def initialize(business:)
    @business = business
  end

  def install!
    raise ArgumentError, 'Deploy a website for this tenant before installing the watermark.' unless deployed?

    FileUtils.mkdir_p(site_root)
    File.binwrite(script_path, File.binread(source_path))

    pages = html_files
    injected = pages.count { |file| inject_into(file) }

    { pages_total: pages.size, pages_injected: injected, script_path: script_path }
  end

  def installed?
    File.file?(script_path) && html_files.any? { |file| tagged?(File.binread(file)) }
  end

  def deployed?
    File.file?(site_root.join('index.html'))
  end

  private

  attr_reader :business

  def inject_into(file)
    html = File.binread(file)
    tag = script_tag

    updated =
      if html.match?(EXISTING_TAG)
        html.gsub(EXISTING_TAG, tag)
      elsif html.match?(BODY_CLOSE)
        html.sub(BODY_CLOSE) { |close| "#{tag}\n#{close}" }
      else
        "#{html}\n#{tag}\n"
      end

    return false if updated == html

    File.binwrite(file, updated)
    true
  end

  def tagged?(html)
    html.include?(MARKER)
  end

  # Tenant assets are served with a one-year immutable cache, so the URL has to
  # change whenever the script does or returning visitors keep the stale copy.
  def script_tag
    %(<script src="/#{SCRIPT_FILENAME}?v=#{script_version}" defer #{MARKER}></script>)
  end

  def script_version
    @script_version ||= Digest::SHA256.hexdigest(File.binread(source_path))[0, 12]
  end

  def html_files
    @html_files ||= Dir.glob(site_root.join('**', '*.html').to_s).first(50_000).select { |file| File.file?(file) }
  end

  def source_path
    Rails.root.join('app', 'javascript', 'tenant_watermark.js')
  end

  def script_path
    site_root.join(SCRIPT_FILENAME)
  end

  def site_root
    Rails.root.join('public', 'tenant_sites', business.subdomain.to_s)
  end
end
