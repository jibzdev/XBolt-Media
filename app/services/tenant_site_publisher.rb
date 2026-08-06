require 'fileutils'
require 'tmpdir'

class TenantSitePublisher
  KEEP_BACKUPS = 3

  def initialize(business:, pages:, editor: false)
    @business = business
    @pages = Array(pages).sort_by { |page| [page.position.to_i, page.id.to_i] }
    @editor = editor
  end

  def publish!
    raise ArgumentError, 'No website pages found. Create at least one page first.' if @pages.blank?
    raise ArgumentError, 'A homepage is required before publishing.' unless @pages.any?(&:home?)

    site_root = Rails.root.join('public', 'tenant_sites', @business.subdomain.to_s)
    backups_root = Rails.root.join('public', 'tenant_sites_backups', @business.subdomain.to_s)

    FileUtils.mkdir_p(site_root.parent)
    FileUtils.mkdir_p(backups_root)

    Dir.mktmpdir("tenant-builder-#{@business.subdomain}-") do |tmp|
      build_root = Pathname.new(File.join(tmp, 'site'))
      FileUtils.mkdir_p(build_root)

      @pages.each do |page|
        write_page!(build_root, page)
      end

      raise ArgumentError, 'Published site did not generate index.html.' unless File.file?(build_root.join('index.html'))

      if Dir.exist?(site_root)
        backup_path = backups_root.join(Time.current.utc.strftime('%Y%m%d-%H%M%S-builder'))
        FileUtils.mkdir_p(backup_path.parent)
        FileUtils.mv(site_root, backup_path)
      end

      FileUtils.mv(build_root, site_root)
    end

    TenantSitemapInstaller.new(business: @business).install!
    cleanup_old_backups!(backups_root)
  end

  def render_page(page)
    page_map = @pages.index_by(&:slug)
    render_document(page, page_map)
  end

  private

  def write_page!(build_root, page)
    rel = page.output_path
    raise ArgumentError, 'Invalid page path.' if rel.include?('..')

    abs = build_root.join(rel).cleanpath
    unless abs.to_s.start_with?(build_root.to_s)
      raise ArgumentError, 'Invalid page path.'
    end

    FileUtils.mkdir_p(abs.dirname)
    File.write(abs, render_document(page, @pages.index_by(&:slug)))
  end

  def render_document(page, page_map)
    title = h(page.title.presence || @business.name)
    nav = render_nav(page_map, page.slug)
    body = page.sections.each_with_index.map { |section, index| render_section(section, index) }.join("\n")

    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>#{title} | #{h(@business.name)}</title>
        <meta name="description" content="#{h(@business.description.to_s.first(155))}">
        <style>
          :root{color-scheme:light;--bg:#ffffff;--text:#18181b;--muted:#71717a;--border:#e4e4e7;--soft:#f4f4f5;--dark:#09090b}
          *{box-sizing:border-box}body{margin:0;font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:var(--text);background:var(--bg);line-height:1.6}
          a{color:inherit}.xb-container{width:min(1120px,calc(100% - 32px));margin:0 auto}.xb-nav{position:sticky;top:0;z-index:20;background:rgba(255,255,255,.92);backdrop-filter:blur(14px);border-bottom:1px solid var(--border)}
          .xb-nav-inner{height:64px;display:flex;align-items:center;justify-content:space-between;gap:18px}.xb-brand{font-weight:800;text-decoration:none;letter-spacing:-.03em}.xb-menu{display:flex;flex-wrap:wrap;gap:8px;align-items:center}.xb-menu a{font-size:14px;text-decoration:none;color:var(--muted);padding:7px 10px;border-radius:999px}.xb-menu a[aria-current="page"],.xb-menu a:hover{background:var(--dark);color:white}
          .xb-section{padding:76px 0}.xb-eyebrow{text-transform:uppercase;letter-spacing:.14em;font-size:12px;font-weight:700;color:var(--muted);margin-bottom:14px}.xb-h1{font-size:clamp(42px,8vw,82px);line-height:.95;letter-spacing:-.07em;margin:0}.xb-h2{font-size:clamp(28px,4vw,46px);line-height:1.05;letter-spacing:-.045em;margin:0}.xb-lead{font-size:18px;color:var(--muted);max-width:720px}.xb-button{display:inline-flex;align-items:center;justify-content:center;margin-top:22px;padding:12px 18px;border-radius:999px;background:var(--dark);color:white;text-decoration:none;font-weight:700;font-size:14px}.xb-grid{display:grid;gap:22px}.xb-two{grid-template-columns:repeat(2,minmax(0,1fr));align-items:center}.xb-card{border:1px solid var(--border);border-radius:22px;padding:22px;background:white;box-shadow:0 18px 40px -32px rgba(0,0,0,.35)}.xb-image{width:100%;border-radius:28px;object-fit:cover;max-height:520px;background:var(--soft)}
          .xb-gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:16px}.xb-contact{display:grid;gap:12px;max-width:620px}.xb-contact input,.xb-contact textarea{width:100%;border:1px solid var(--border);border-radius:14px;padding:13px 14px;font:inherit}.xb-contact button{border:0;cursor:pointer}.xb-faq{border-top:1px solid var(--border);padding:18px 0}.xb-footer{padding:32px 0;border-top:1px solid var(--border);color:var(--muted);font-size:14px}
          #{editor_styles}
          @media(max-width:760px){.xb-nav-inner{height:auto;min-height:64px;align-items:flex-start;flex-direction:column;padding:14px 0}.xb-menu{gap:4px}.xb-two{grid-template-columns:1fr}.xb-section{padding:52px 0}.xb-h1{font-size:44px}}
        </style>
      </head>
      <body>
        #{nav}
        <main>
          #{body}
        </main>
        <footer class="xb-footer"><div class="xb-container">&copy; #{Time.current.year} #{h(@business.name)}. Built with XBolt Media.</div></footer>
      </body>
      </html>
    HTML
  end

  def render_nav(page_map, current_slug)
    links = page_map.values.sort_by { |page| [page.position.to_i, page.id.to_i] }.map do |page|
      href = page.home? ? '/' : page.slug
      current = page.slug == current_slug ? ' aria-current="page"' : ''
      %(<a href="#{h(href)}"#{current}>#{h(page.title)}</a>)
    end.join

    <<~HTML
      <header class="xb-nav">
        <div class="xb-container xb-nav-inner">
          <a class="xb-brand" href="/">#{h(@business.name)}</a>
          <nav class="xb-menu" aria-label="Primary navigation">#{links}</nav>
        </div>
      </header>
    HTML
  end

  def editor_styles
    return '' unless @editor

    '[data-xbolt-editable]{outline:2px solid transparent;outline-offset:4px;border-radius:8px;cursor:pointer;transition:outline-color .15s,background .15s}[data-xbolt-editable]:hover{outline-color:#f59e0b;background:rgba(245,158,11,.08)}[data-xbolt-selected]{outline-color:#f59e0b!important;background:rgba(245,158,11,.14)!important}[data-xbolt-section]{position:relative}[data-xbolt-section]:hover{box-shadow:inset 0 0 0 1px rgba(245,158,11,.45)}[data-xbolt-items]{min-height:24px}.xbolt-drag-ghost{opacity:.45}'
  end

  def render_section(section, index)
    type = section['type'].to_s

    case type
    when 'hero' then render_hero(section, index)
    when 'text' then render_text(section, index)
    when 'image' then render_image(section, index)
    when 'split' then render_split(section, index)
    when 'gallery' then render_gallery(section, index)
    when 'cards' then render_cards(section, index)
    when 'testimonials' then render_testimonials(section, index)
    when 'cta' then render_cta(section, index)
    when 'contact_form' then render_contact_form(section, index)
    when 'faq' then render_faq(section, index)
    else ''
    end
  end

  def render_hero(section, index)
    image = image_tag_for(section)
    <<~HTML
      <section class="xb-section" #{section_attrs(index)} style="background:linear-gradient(135deg,#09090b,#27272a);color:white">
        <div class="xb-container xb-grid xb-two">
          <div>
            #{content_tag('div', section['eyebrow'], class_name: 'xb-eyebrow', attrs: edit_attrs(index, 'eyebrow')) if section['eyebrow'].present?}
            <h1 class="xb-h1" #{edit_attrs(index, 'heading')}>#{h(section['heading'].presence || @business.name)}</h1>
            #{paragraph(section['body'], class_name: 'xb-lead', color: '#d4d4d8', attrs: edit_attrs(index, 'body'))}
            #{button(section, section_index: index)}
          </div>
          #{image}
        </div>
      </section>
    HTML
  end

  def render_text(section, index)
    <<~HTML
      <section class="xb-section" #{section_attrs(index)}>
        <div class="xb-container">
          <h2 class="xb-h2" #{edit_attrs(index, 'heading')}>#{h(section['heading'])}</h2>
          #{paragraph(section['body'], class_name: 'xb-lead', attrs: edit_attrs(index, 'body'))}
        </div>
      </section>
    HTML
  end

  def render_image(section, index)
    <<~HTML
      <section class="xb-section" #{section_attrs(index)}>
        <div class="xb-container">
          <h2 class="xb-h2" #{edit_attrs(index, 'heading')}>#{h(section['heading'])}</h2>
          #{paragraph(section['body'], class_name: 'xb-lead', attrs: edit_attrs(index, 'body'))}
          #{image_tag_for(section)}
        </div>
      </section>
    HTML
  end

  def render_split(section, index)
    <<~HTML
      <section class="xb-section" #{section_attrs(index)}>
        <div class="xb-container xb-grid xb-two">
          #{image_tag_for(section)}
          <div>
            <h2 class="xb-h2" #{edit_attrs(index, 'heading')}>#{h(section['heading'])}</h2>
            #{paragraph(section['body'], class_name: 'xb-lead', attrs: edit_attrs(index, 'body'))}
            #{button(section, section_index: index)}
          </div>
        </div>
      </section>
    HTML
  end

  def render_gallery(section, index)
    category = section['category'].to_s
    category_attr = category.present? ? %( data-xbolt-gallery-category="#{h(category)}") : ''
    <<~HTML
      <section class="xb-section" #{section_attrs(index)}>
        <div class="xb-container">
          <h2 class="xb-h2" #{edit_attrs(index, 'heading')}>#{h(section['heading'].presence || 'Gallery')}</h2>
          #{paragraph(section['body'], class_name: 'xb-lead', attrs: edit_attrs(index, 'body'))}
          <div class="xb-gallery" data-xbolt-gallery#{category_attr}></div>
        </div>
      </section>
    HTML
  end

  def render_cards(section, index)
    items = Array(section['items']).each_with_index.map do |item, item_index|
      <<~HTML
        <article class="xb-card" #{item_attrs(index, 'items', item_index)}>
          <h3 #{edit_attrs(index, 'title', item_key: 'items', item_index: item_index)}>#{h(item['title'])}</h3>
          #{content_tag('p', item['subtitle'], class_name: nil, attrs: edit_attrs(index, 'subtitle', item_key: 'items', item_index: item_index)) if item['subtitle'].present?}
          #{paragraph(item['body'], attrs: edit_attrs(index, 'body', item_key: 'items', item_index: item_index))}
        </article>
      HTML
    end.join

    <<~HTML
      <section class="xb-section" #{section_attrs(index)}>
        <div class="xb-container">
          <h2 class="xb-h2" #{edit_attrs(index, 'heading')}>#{h(section['heading'])}</h2>
          #{paragraph(section['body'], class_name: 'xb-lead', attrs: edit_attrs(index, 'body'))}
          <div class="xb-grid" #{items_attrs(index, 'items')} style="grid-template-columns:repeat(auto-fit,minmax(220px,1fr));margin-top:28px">#{items}</div>
        </div>
      </section>
    HTML
  end

  def render_testimonials(section, index)
    items = Array(section['items']).each_with_index.map do |item, item_index|
      <<~HTML
        <figure class="xb-card" #{item_attrs(index, 'items', item_index)}>
          <blockquote #{edit_attrs(index, 'quote', item_key: 'items', item_index: item_index)}>#{h(item['quote'])}</blockquote>
          <figcaption><strong #{edit_attrs(index, 'name', item_key: 'items', item_index: item_index)}>#{h(item['name'])}</strong><br><span style="color:var(--muted)" #{edit_attrs(index, 'role', item_key: 'items', item_index: item_index)}>#{h(item['role'])}</span></figcaption>
        </figure>
      HTML
    end.join

    <<~HTML
      <section class="xb-section" #{section_attrs(index)} style="background:var(--soft)">
        <div class="xb-container">
          <h2 class="xb-h2" #{edit_attrs(index, 'heading')}>#{h(section['heading'])}</h2>
          #{paragraph(section['body'], class_name: 'xb-lead', attrs: edit_attrs(index, 'body'))}
          <div class="xb-grid" #{items_attrs(index, 'items')} style="grid-template-columns:repeat(auto-fit,minmax(260px,1fr));margin-top:28px">#{items}</div>
        </div>
      </section>
    HTML
  end

  def render_cta(section, index)
    <<~HTML
      <section class="xb-section" #{section_attrs(index)}>
        <div class="xb-container xb-card" style="text-align:center;background:#09090b;color:white">
          <h2 class="xb-h2" #{edit_attrs(index, 'heading')}>#{h(section['heading'])}</h2>
          #{paragraph(section['body'], class_name: 'xb-lead', color: '#d4d4d8', attrs: edit_attrs(index, 'body'))}
          #{button(section, inverse: true, section_index: index)}
        </div>
      </section>
    HTML
  end

  def render_contact_form(section, index)
    <<~HTML
      <section class="xb-section" #{section_attrs(index)}>
        <div class="xb-container">
          <h2 class="xb-h2" #{edit_attrs(index, 'heading')}>#{h(section['heading'].presence || 'Contact us')}</h2>
          #{paragraph(section['body'], class_name: 'xb-lead', attrs: edit_attrs(index, 'body'))}
          <form class="xb-contact" action="/contact" method="post">
            <input type="text" name="name" placeholder="Your name" required>
            <input type="email" name="email" placeholder="Email address" required>
            <input type="tel" name="phone" placeholder="Phone number">
            <textarea name="message" rows="5" placeholder="How can we help?" required></textarea>
            <button class="xb-button" type="submit">Send message</button>
          </form>
        </div>
      </section>
    HTML
  end

  def render_faq(section, index)
    items = Array(section['faqs']).each_with_index.map do |item, item_index|
      <<~HTML
        <div class="xb-faq" #{item_attrs(index, 'faqs', item_index)}>
          <h3 #{edit_attrs(index, 'question', item_key: 'faqs', item_index: item_index)}>#{h(item['question'])}</h3>
          #{paragraph(item['answer'], attrs: edit_attrs(index, 'answer', item_key: 'faqs', item_index: item_index))}
        </div>
      HTML
    end.join

    <<~HTML
      <section class="xb-section" #{section_attrs(index)}>
        <div class="xb-container">
          <h2 class="xb-h2" #{edit_attrs(index, 'heading')}>#{h(section['heading'])}</h2>
          #{paragraph(section['body'], class_name: 'xb-lead', attrs: edit_attrs(index, 'body'))}
          <div #{items_attrs(index, 'faqs')} style="margin-top:28px">#{items}</div>
        </div>
      </section>
    HTML
  end

  def image_tag_for(section)
    src = asset_url(section['image_key'])
    return '' if src.blank?

    %(<img class="xb-image" src="#{h(src)}" alt="#{h(section['image_alt'].presence || section['heading'])}" loading="lazy">)
  end

  def asset_url(key)
    return nil if key.blank?

    blob = asset_blobs_by_key[key.to_s]
    return nil if blob.nil?

    Rails.application.routes.url_helpers.media_asset_path(key: blob.key)
  end

  def asset_blobs_by_key
    @asset_blobs_by_key ||= @business.assets_attachments.includes(:blob).each_with_object({}) do |attachment, memo|
      memo[attachment.blob.key] = attachment.blob
    end
  end

  def button(section, inverse: false, section_index: nil)
    text = section['button_text'].to_s
    url = safe_url(section['button_url'])
    return '' if text.blank? || url.blank?

    style = inverse ? ' style="background:white;color:#09090b"' : ''
    %(<a class="xb-button" href="#{h(url)}"#{style} #{edit_attrs(section_index, 'button_text')}>#{h(text)}</a>)
  end

  def safe_url(value)
    url = value.to_s.strip
    return nil if url.blank?
    return url if url.start_with?('/', '#', 'mailto:', 'tel:')
    return url if url.start_with?('https://')

    nil
  end

  def paragraph(value, class_name: nil, color: nil, attrs: nil)
    return '' if value.blank?

    classes = class_name.present? ? %( class="#{h(class_name)}") : ''
    style = color.present? ? %( style="color:#{h(color)}") : ''
    %(<p#{classes}#{style} #{attrs}>#{h(value).gsub("\n", '<br>')}</p>)
  end

  def content_tag(tag, value, class_name: nil, attrs: nil)
    classes = class_name.present? ? %( class="#{h(class_name)}") : ''
    %(<#{tag}#{classes} #{attrs}>#{h(value)}</#{tag}>)
  end

  def section_attrs(index)
    return '' unless @editor

    %(data-xbolt-section data-xbolt-section-index="#{index}")
  end

  def items_attrs(section_index, item_key)
    return '' unless @editor

    %(data-xbolt-items data-xbolt-section-index="#{section_index}" data-xbolt-item-key="#{h(item_key)}")
  end

  def item_attrs(section_index, item_key, item_index)
    return '' unless @editor

    %(data-xbolt-item data-xbolt-section-index="#{section_index}" data-xbolt-item-key="#{h(item_key)}" data-xbolt-item-index="#{item_index}")
  end

  def edit_attrs(section_index, field, item_key: nil, item_index: nil)
    return '' unless @editor && section_index.present? && field.present?

    attrs = %(data-xbolt-editable="true" data-xbolt-section-index="#{section_index}" data-xbolt-field="#{h(field)}")
    attrs += %( data-xbolt-item-key="#{h(item_key)}" data-xbolt-item-index="#{item_index}") if item_key.present? && item_index.present?
    attrs
  end

  def h(value)
    ERB::Util.html_escape(value.to_s)
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
