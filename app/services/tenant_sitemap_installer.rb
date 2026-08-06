require 'fileutils'

class TenantSitemapInstaller
  def initialize(business:)
    @business = business
  end

  def install!
    FileUtils.mkdir_p(site_root)
    File.write(sitemap_path, sitemap_xml)
    sitemap_path
  end

  private

  attr_reader :business

  def sitemap_xml
    urls = html_paths.map do |path, lastmod|
      {
        loc: "#{base_url}#{path}",
        lastmod: lastmod,
        changefreq: 'weekly',
        priority: path == '/' ? '1.0' : '0.8'
      }
    end

    SitemapXmlBuilder.build(urls)
  end

  def html_paths
    index_path = site_root.join('index.html')
    return [['/', business.updated_at || Time.current]] unless File.file?(index_path)

    Dir.glob(site_root.join('**', '*.html').to_s).first(50_000).map do |file|
      rel = Pathname.new(file).relative_path_from(site_root).to_s.tr('\\', '/')
      [route_for(rel), File.mtime(file)]
    end.uniq { |path, _lastmod| path }.sort_by(&:first)
  end

  def route_for(relative_html_path)
    return '/' if relative_html_path == 'index.html'

    "/#{relative_html_path.delete_suffix('/index.html').delete_suffix('.html')}"
  end

  def base_url
    host =
      if business.custom_domain.present? && business.custom_domain_status == 'active'
        business.custom_domain
      else
        business.full_subdomain
      end

    "https://#{host.to_s.delete_suffix('/')}"
  end

  def site_root
    Rails.root.join('public', 'tenant_sites', business.subdomain.to_s)
  end

  def sitemap_path
    site_root.join('sitemap.xml')
  end
end
