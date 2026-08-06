module SeoHelper
  def seo_meta_tags(page_name = nil)
    seo_setting = page_name ? SeoSetting.for_page(page_name) : nil
    # Be defensive: if a relation is returned or nil, normalize
    seo_setting = seo_setting.first if seo_setting.is_a?(ActiveRecord::Relation)
    return generate_meta_tags(seo_setting.meta_tags) if seo_setting&.respond_to?(:meta_tags)
    generate_default_meta_tags
  end

  def generate_meta_tags(meta_tags)
    tags = []
    
    # Primary Meta Tags
    tags << tag(:meta, charset: 'UTF-8')
    tags << tag(:meta, name: 'viewport', content: 'width=device-width, initial-scale=1.0')
    tags << tag(:meta, name: 'title', content: meta_tags[:title])
    tags << tag(:meta, name: 'description', content: meta_tags[:description])
    tags << tag(:meta, name: 'keywords', content: meta_tags[:keywords])
    tags << tag(:meta, name: 'author', content: meta_tags[:author])
    tags << tag(:meta, name: 'robots', content: meta_tags[:robots])
    
    # Open Graph / Facebook
    tags << tag(:meta, property: 'og:type', content: meta_tags[:og_type])
    tags << tag(:meta, property: 'og:url', content: meta_tags[:og_url])
    tags << tag(:meta, property: 'og:title', content: meta_tags[:og_title])
    tags << tag(:meta, property: 'og:description', content: meta_tags[:og_description])
    tags << tag(:meta, property: 'og:image', content: meta_tags[:og_image])
    
    # Twitter
    tags << tag(:meta, property: 'twitter:card', content: meta_tags[:twitter_card])
    tags << tag(:meta, property: 'twitter:url', content: meta_tags[:twitter_url])
    tags << tag(:meta, property: 'twitter:title', content: meta_tags[:twitter_title])
    tags << tag(:meta, property: 'twitter:description', content: meta_tags[:twitter_description])
    tags << tag(:meta, property: 'twitter:image', content: meta_tags[:twitter_image])
    
    # Favicon
    tags << tag(:link, rel: 'icon', type: 'image/png', href: meta_tags[:favicon_url]) if meta_tags[:favicon_url].present?
    tags << tag(:link, rel: 'apple-touch-icon', href: meta_tags[:apple_touch_icon_url]) if meta_tags[:apple_touch_icon_url].present?
    
    # Canonical URL
    tags << tag(:link, rel: 'canonical', href: meta_tags[:canonical_url]) if meta_tags[:canonical_url].present?
    
    # Structured Data
    tags << structured_data_tag(meta_tags[:structured_data]) if meta_tags[:structured_data].present?
    
    safe_join(tags.compact)
  end

  def generate_default_meta_tags
    tags = []
    
    tags << tag(:meta, charset: 'UTF-8')
    tags << tag(:meta, name: 'viewport', content: 'width=device-width, initial-scale=1.0')
    tags << tag(:meta, name: 'title', content: 'XBolt - Digital Studio')
    tags << tag(:meta, name: 'description', content: 'XBolt builds fast, modern websites and digital experiences. Design, development, and ongoing support.')
    tags << tag(:meta, name: 'keywords', content: 'web design, web development, branding, digital studio, SEO, performance, hosting')
    tags << tag(:meta, name: 'author', content: 'XBolt')
    tags << tag(:meta, name: 'robots', content: 'index, follow')
    
    # Open Graph
    tags << tag(:meta, property: 'og:type', content: 'website')
    tags << tag(:meta, property: 'og:title', content: 'XBolt - Digital Studio')
    tags << tag(:meta, property: 'og:description', content: 'XBolt builds fast, modern websites and digital experiences.')
    tags << tag(:meta, property: 'og:image', content: absolute_public_asset_url('/assets/images/logo4.png'))
    
    # Twitter
    tags << tag(:meta, property: 'twitter:card', content: 'summary_large_image')
    tags << tag(:meta, property: 'twitter:title', content: 'XBolt - Digital Studio')
    tags << tag(:meta, property: 'twitter:description', content: 'XBolt builds fast, modern websites and digital experiences.')
    tags << tag(:meta, property: 'twitter:image', content: absolute_public_asset_url('/assets/images/logo4.png'))
    
    # Favicon
    tags << tag(:link, rel: 'icon', type: 'image/png', href: absolute_public_asset_url('/assets/images/logo4.png'))
    tags << tag(:link, rel: 'apple-touch-icon', href: absolute_public_asset_url('/assets/images/logo4.png'))
    
    safe_join(tags)
  end

  # Avoid sprockets lookups for static public files (e.g. /public/assets/images/*).
  # In production, assets.compile is false, so asset_url() will raise if the file
  # isn't in the pipeline. These images are served directly by public_file_server/nginx.
  def absolute_public_asset_url(path)
    p = path.to_s
    p = "/#{p}" unless p.start_with?('/')
    if respond_to?(:request) && request&.base_url.present?
      "#{request.base_url}#{p}"
    else
      p
    end
  end

  def structured_data_tag(json_ld)
    return unless json_ld.present?
    
    begin
      # Validate JSON
      JSON.parse(json_ld)
      tag(:script, type: 'application/ld+json') { json_ld.html_safe }
    rescue JSON::ParserError
      Rails.logger.warn "Invalid JSON-LD structured data: #{json_ld}"
      nil
    end
  end

  def seo_title(page_name = nil)
    seo_setting = page_name ? SeoSetting.for_page(page_name) : nil
    seo_setting&.title || 'XBolt - Digital Studio'
  end

  def seo_description(page_name = nil)
    seo_setting = page_name ? SeoSetting.for_page(page_name) : nil
    seo_setting&.description || 'XBolt builds fast, modern websites and digital experiences. Design, development, and ongoing support.'
  end
end
