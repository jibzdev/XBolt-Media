module ApplicationHelper
  include SeoHelper

  def current_general_setting
    @general_setting ||= GeneralSetting.first_or_initialize
  end

  def brand_logo_url
    url = current_general_setting.logo_url.to_s.strip
    url.present? ? url : "/assets/images/logo3.png"
  end

  def brand_favicon_url
    url = current_general_setting.favicon_url.to_s.strip
    url.present? ? url : "/assets/images/logo4.png"
  end

  # Defaults preserve the URLs that were hardcoded in the footer before these
  # became editable, so the site looks unchanged until an admin overrides them.
  SOCIAL_LINK_DEFAULTS = {
    tiktok: { label: "TikTok", icon: "bxl-tiktok", default: "https://tiktok.com/@xboltmedia" },
    instagram: { label: "Instagram", icon: "bxl-instagram", default: "https://instagram.com/xboltmedia" },
    linkedin: { label: "LinkedIn", icon: "bxl-linkedin", default: "https://www.linkedin.com/company/xbolt-media/" },
    facebook: { label: "Facebook", icon: "bxl-facebook", default: nil }
  }.freeze

  def social_links
    gs = current_general_setting

    SOCIAL_LINK_DEFAULTS.filter_map do |platform, config|
      configured = gs.public_send("#{platform}_url").to_s.strip
      url = configured.presence || config[:default]
      next if url.blank?

      { platform: platform, label: config[:label], icon: config[:icon], url: url }
    end
  end

  def google_reviews_url
    current_general_setting.google_reviews_url.to_s.strip.presence
  end

  def absolute_url(url_or_path)
    s = url_or_path.to_s.strip
    return s if s.start_with?("http://", "https://")
    s = "/#{s}" unless s.start_with?("/")

    if respond_to?(:request) && request&.base_url.present?
      return "#{request.base_url}#{s}"
    end

    host = Rails.application.routes.default_url_options[:host].to_s.strip
    protocol = Rails.application.routes.default_url_options[:protocol].presence || "https://"
    host.present? ? "#{protocol}#{host}#{s}" : s
  end

  def theme_css_variables
    gs = current_general_setting

    primary = gs.theme_primary.presence || "#f59e0b"
    primary_hover = gs.theme_primary_hover.presence || "#d97706"
    on_primary = gs.theme_on_primary.presence || "#09090b"
    bg = gs.theme_bg.presence || "#09090b"
    surface = gs.theme_surface.presence || "#111113"
    surface_alt = gs.theme_surface_alt.presence || "#18181b"
    border = gs.theme_border.presence || "#27272a"
    text = gs.theme_text.presence || "#fafafa"
    text_muted = gs.theme_text_muted.presence || "#a1a1aa"

    <<~CSS.html_safe
      :root{
        --xbolt-primary: #{ERB::Util.html_escape(primary)};
        --xbolt-primary-hover: #{ERB::Util.html_escape(primary_hover)};
        --xbolt-on-primary: #{ERB::Util.html_escape(on_primary)};
        --xbolt-bg: #{ERB::Util.html_escape(bg)};
        --xbolt-surface: #{ERB::Util.html_escape(surface)};
        --xbolt-surface-alt: #{ERB::Util.html_escape(surface_alt)};
        --xbolt-border: #{ERB::Util.html_escape(border)};
        --xbolt-text: #{ERB::Util.html_escape(text)};
        --xbolt-text-muted: #{ERB::Util.html_escape(text_muted)};

        --xbolt-primary-rgb: #{hex_to_rgb(primary)};
        --xbolt-text-rgb: #{hex_to_rgb(text)};
        --xbolt-bg-rgb: #{hex_to_rgb(bg)};
        --xbolt-surface-rgb: #{hex_to_rgb(surface)};
        --xbolt-surface-alt-rgb: #{hex_to_rgb(surface_alt)};
        --xbolt-border-rgb: #{hex_to_rgb(border)};
        --xbolt-text-muted-rgb: #{hex_to_rgb(text_muted)};
      }
    CSS
  end

  def hex_to_rgb(hex)
    h = hex.to_s.delete_prefix("#")
    if h.length == 3
      r = (h[0] * 2).to_i(16)
      g = (h[1] * 2).to_i(16)
      b = (h[2] * 2).to_i(16)
    else
      r = h[0, 2].to_i(16)
      g = h[2, 2].to_i(16)
      b = h[4, 2].to_i(16)
    end
    "#{r} #{g} #{b}"
  rescue StandardError
    "24 24 27"
  end

  def active_class(link_path)
    current_page?(link_path) ? "bg-zinc-100 text-zinc-900" : "text-zinc-400"
  end

  def category_open?(paths)
    paths.any? { |path| current_page?(path) } ? "block" : "hidden"
  end

  def business_site_url(business)
    return root_url if business.nil?

    custom = business.custom_domain.to_s.strip
    if custom.present?
      return custom if custom.start_with?('http://', 'https://')
      return "#{request.protocol}#{custom}"
    end

    base = Rails.application.routes.default_url_options[:host].to_s
    base = request.host_with_port.to_s if base.blank?

    host, port = base.split(':', 2)
    host = host.to_s.strip
    port = port.to_s.strip

    # Common dev host
    if host == 'localhost'
      return "#{request.protocol}#{business.subdomain}.localhost#{port.present? ? ":#{port}" : ''}"
    end

    # Production / custom base domain
    tenant_host = "#{business.subdomain}.#{host}"
    "#{request.protocol}#{tenant_host}"
  end
end