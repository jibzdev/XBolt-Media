require 'tmpdir'
require 'fileutils'
require 'zip'
require 'nokogiri'
require 'set'

class TenantSiteDeployer
  MAX_ZIP_BYTES = 200 * 1024 * 1024 # 200MB
  MAX_UNZIPPED_BYTES = 500 * 1024 * 1024 # 500MB (zip-bomb guard)
  KEEP_BACKUPS = 3

  def initialize(business:, uploaded_zip:)
    @business = business
    @uploaded_zip = uploaded_zip
  end

  def deploy!
    validate_upload!

    site_root = Rails.root.join('public', 'tenant_sites', @business.subdomain.to_s)
    backups_root = Rails.root.join('public', 'tenant_sites_backups', @business.subdomain.to_s)

    FileUtils.mkdir_p(site_root.parent)
    FileUtils.mkdir_p(backups_root)

    Dir.mktmpdir("tenant-site-#{@business.subdomain}-") do |tmp|
      extract_dir = File.join(tmp, 'extracted')
      FileUtils.mkdir_p(extract_dir)

      extract_zip_to!(@uploaded_zip.path, extract_dir)
      root = normalize_extracted_root(extract_dir)
      ensure_index_html!(root)
      ensure_no_symlinks!(root)
      warnings = validate_referenced_assets(root)

      # Atomic-ish swap: move current to backup, move new into place.
      if Dir.exist?(site_root)
        backup_path = backups_root.join(Time.current.utc.strftime('%Y%m%d-%H%M%S'))
        FileUtils.mkdir_p(backup_path.parent)
        FileUtils.mv(site_root, backup_path)
      end

      FileUtils.mv(root, site_root)
      @warnings = warnings
    end

    TenantSitemapInstaller.new(business: @business).install!
    cleanup_old_backups!(backups_root)
    @warnings || []
  end

  private

  def validate_upload!
    raise ArgumentError, 'No ZIP file uploaded.' unless @uploaded_zip.respond_to?(:path)

    name = @uploaded_zip.original_filename.to_s
    raise ArgumentError, 'Please upload a .zip file.' unless File.extname(name).downcase == '.zip'

    size = @uploaded_zip.size.to_i
    raise ArgumentError, "ZIP too large (max #{MAX_ZIP_BYTES / (1024 * 1024)}MB)." if size > MAX_ZIP_BYTES
  end

  def extract_zip_to!(zip_path, extract_dir)
    extract_dir_expanded = File.expand_path(extract_dir)
    total_unzipped = 0

    Zip::File.open(zip_path) do |zip|
      zip.each do |entry|
        next if entry.name.to_s.start_with?('__MACOSX/')
        next if entry.name.to_s.end_with?('/') # directory entry

        total_unzipped += entry.size.to_i
        raise ArgumentError, 'ZIP contents too large.' if total_unzipped > MAX_UNZIPPED_BYTES

        dest = File.expand_path(File.join(extract_dir, entry.name.to_s), extract_dir)
        unless dest.start_with?(extract_dir_expanded + File::SEPARATOR) || dest == extract_dir_expanded
          raise ArgumentError, 'Invalid ZIP (path traversal detected).'
        end

        FileUtils.mkdir_p(File.dirname(dest))
        entry.extract(dest) { true }
      end
    end
  end

  def normalize_extracted_root(extract_dir)
    entries = Dir.children(extract_dir).reject { |n| n.start_with?('__MACOSX') }
    if entries.length == 1
      only = File.join(extract_dir, entries.first)
      return only if File.directory?(only)
    end
    extract_dir
  end

  def ensure_index_html!(root)
    index = File.join(root, 'index.html')
    raise ArgumentError, 'ZIP must contain index.html at the site root.' unless File.file?(index)
  end

  def ensure_no_symlinks!(root)
    Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).each do |path|
      next if ['.', '..'].include?(File.basename(path))
      st = File.lstat(path) rescue nil
      next if st.nil?
      raise ArgumentError, 'ZIP contains symlinks (not allowed).' if st.symlink?
    end
  end

  # Deterministic “fix issues” approach:
  # we validate that index.html references files that exist in the ZIP.
  # This catches 90% of broken deploys (wrong base path, missing assets, etc.).
  def validate_referenced_assets(root)
    index_path = File.join(root, 'index.html')
    html = File.read(index_path)
    doc = Nokogiri::HTML(html)

    refs = Set.new

    doc.css('link[href]').each { |n| refs << n['href'].to_s }
    doc.css('script[src]').each { |n| refs << n['src'].to_s }
    doc.css('img[src]').each { |n| refs << n['src'].to_s }
    doc.css('source[src]').each { |n| refs << n['src'].to_s }
    doc.css('source[srcset]').each do |n|
      n['srcset'].to_s.split(',').each do |part|
        refs << part.strip.split(/\s+/).first.to_s
      end
    end

    missing = []
    refs.each do |raw|
      next if raw.blank?
      next if raw.start_with?('http://', 'https://', '//', 'data:', 'mailto:', 'tel:')

      # Ignore anchors and query-only
      next if raw.start_with?('#')

      path = raw.split('#').first.to_s.split('?').first.to_s
      next if path.blank?

      # If it's absolute (/assets/app.css), treat as root-relative inside the tenant folder
      rel = path.sub(%r{\A/+}, '')

      candidate = File.join(root, rel)
      next if File.file?(candidate)

      missing << raw
    end

    missing.uniq.take(15)
  rescue StandardError
    []
  end

  def cleanup_old_backups!(backups_root)
    backups = Dir.children(backups_root).sort.reverse
    backups.drop(KEEP_BACKUPS).each do |old|
      FileUtils.rm_rf(backups_root.join(old))
    end
  rescue StandardError
    nil
  end
end

