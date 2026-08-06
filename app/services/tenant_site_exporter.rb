require 'fileutils'
require 'securerandom'
require 'zip'

class TenantSiteExporter
  def initialize(business:)
    @business = business
  end

  # Builds a zip of the CURRENT deployed site folder and writes it to zip_path.
  # zip_path should be a full path to a .zip file (it will be replaced).
  def export_to!(zip_path)
    site_root = Rails.root.join('public', 'tenant_sites', @business.subdomain.to_s)
    index = site_root.join('index.html')
    raise ArgumentError, 'No deployed site found for this business.' unless File.file?(index)

    FileUtils.mkdir_p(File.dirname(zip_path))

    tmp = "#{zip_path}.tmp-#{SecureRandom.hex(6)}"
    FileUtils.rm_f(tmp)

    Zip::File.open(tmp, create: true) do |zip|
      Dir.glob(site_root.join('**', '*'), File::FNM_DOTMATCH).each do |abs|
        next if File.directory?(abs)

        base = File.basename(abs.to_s)
        next if base == '.' || base == '..'

        rel = Pathname.new(abs.to_s).relative_path_from(site_root).to_s
        next if rel.start_with?('..')

        zip.add(rel, abs.to_s)
      end
    end

    FileUtils.mv(tmp, zip_path)
  ensure
    FileUtils.rm_f(tmp) if defined?(tmp) && tmp.present? && File.exist?(tmp)
  end
end

