require 'fileutils'

class TenantSiteDestroyer
  KEEP_BACKUPS = 3

  def initialize(business:)
    @business = business
  end

  def destroy!
    site_root = Rails.root.join('public', 'tenant_sites', @business.subdomain.to_s)
    backups_root = Rails.root.join('public', 'tenant_sites_backups', @business.subdomain.to_s)

    unless Dir.exist?(site_root)
      raise ArgumentError, 'No deployed site folder exists for this business.'
    end

    # If there's no index.html, treat it as "already deleted"
    index = site_root.join('index.html')
    unless File.file?(index)
      FileUtils.rm_rf(site_root)
      raise ArgumentError, 'No deployed website found (already under construction).'
    end

    FileUtils.mkdir_p(backups_root)
    backup_path = backups_root.join("#{Time.current.utc.strftime('%Y%m%d-%H%M%S')}-deleted")
    FileUtils.mv(site_root, backup_path)

    cleanup_old_backups!(backups_root)
  end

  private

  def cleanup_old_backups!(backups_root)
    backups = Dir.children(backups_root).sort.reverse
    backups.drop(KEEP_BACKUPS).each do |old|
      FileUtils.rm_rf(backups_root.join(old))
    end
  rescue StandardError
    nil
  end
end

