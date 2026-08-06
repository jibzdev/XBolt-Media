class SitemapXmlBuilder
  PUBLIC_PATHS = [
    '/',
    '/about',
    '/services',
    '/work',
    '/contact',
    '/terms-of-service',
    '/privacy-policy'
  ].freeze

  class << self
    def main(request:)
      base_url = canonical_base_url(request)
      urls = PUBLIC_PATHS.map do |path|
        {
          loc: absolute_url(base_url, path),
          lastmod: latest_main_lastmod,
          changefreq: path == '/' ? 'weekly' : 'monthly',
          priority: path == '/' ? '1.0' : '0.7'
        }
      end

      build(urls)
    end

    def tenant(business:, request:)
      base_url = "#{request.protocol}#{request.host_with_port}"
      urls = tenant_paths_for(business).map do |path, lastmod|
        {
          loc: absolute_url(base_url, path),
          lastmod: lastmod,
          changefreq: 'weekly',
          priority: path == '/' ? '1.0' : '0.8'
        }
      end

      build(urls)
    end

    def build(urls)
      Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        xml.urlset('xmlns' => 'http://www.sitemaps.org/schemas/sitemap/0.9') do
          urls.each do |item|
            xml.url do
              xml.loc item[:loc]
              xml.lastmod item[:lastmod].to_date.iso8601 if item[:lastmod].present?
              xml.changefreq item[:changefreq]
              xml.priority item[:priority]
            end
          end
        end
      end.to_xml
    end

    private

    def canonical_base_url(request)
      configured = GeneralSetting.first_or_initialize.website_url.presence
      candidate = configured.presence || "#{request.protocol}#{request.host_with_port}"
      candidate.to_s.delete_suffix('/')
    end

    def absolute_url(base_url, path)
      "#{base_url}#{path}"
    end

    def latest_main_lastmod
      [
        SeoSetting.maximum(:updated_at),
        WorkCard.maximum(:updated_at),
        Service.maximum(:updated_at),
        Business.maximum(:updated_at)
      ].compact.max || Time.current
    end

    def tenant_paths_for(business)
      site_root = Rails.root.join('public', 'tenant_sites', business.subdomain.to_s)
      index_path = site_root.join('index.html')
      return [['/', business.updated_at || Time.current]] unless File.file?(index_path)

      html_files = Dir.glob(site_root.join('**', '*.html').to_s).first(50_000)
      paths = html_files.map do |file|
        rel = Pathname.new(file).relative_path_from(site_root).to_s.tr('\\', '/')
        path = tenant_route_for(rel)
        [path, File.mtime(file)]
      end

      paths.uniq { |path, _lastmod| path }.sort_by(&:first)
    end

    def tenant_route_for(relative_html_path)
      return '/' if relative_html_path == 'index.html'

      path = relative_html_path.delete_suffix('/index.html').delete_suffix('.html')
      "/#{path}"
    end
  end
end
