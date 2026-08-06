require 'nokogiri'
require 'fileutils'

class TenantStaticSiteEditor
  TEXT_SELECTOR = 'h1,h2,h3,h4,h5,h6,p,a,button,span,li,blockquote,strong,em,b,i,small,label,figcaption,cite,div,td,th'.freeze
  NON_CONTENT_TAGS = %w[script style noscript svg path img picture video audio source canvas iframe input textarea select option br hr].freeze
  GROUP_HINT = /grid|cards?|reviews?|testimonials?|gallery|work|projects?|services?|features?|team|pricing|plans?|portfolio|case|results?|logos?|columns?|row|list|slider|carousel/i
  ITEM_HINT = /card|review|testimonial|gallery|work|project|service|feature|team|price|plan|portfolio|case|result|item|slide|logo/i
  ASSET_ATTRS = %w[href src poster].freeze

  def initialize(business:)
    @business = business
    @site_root = Rails.root.join('public', 'tenant_sites', @business.subdomain.to_s)
  end

  def deployed?
    File.file?(@site_root.join('index.html'))
  end

  def pages
    return [] unless Dir.exist?(@site_root)

    Dir.glob(@site_root.join('**', '*.html')).filter_map do |abs|
      rel = Pathname.new(abs).relative_path_from(@site_root).to_s.tr('\\', '/')
      {
        path: rel == 'index.html' ? '/' : "/#{rel.delete_suffix('/index.html').delete_suffix('.html')}",
        file: rel,
        title: page_title(abs, rel)
      }
    end.sort_by { |page| page[:path] == '/' ? '' : page[:path] }
  end

  def render_editor_html(path:)
    abs = resolve_html_path(path)
    raise ArgumentError, 'Page not found.' if abs.nil?

    doc = Nokogiri::HTML(File.read(abs))
    rewrite_asset_urls!(doc)
    mark_text_nodes!(doc)
    mark_reorder_groups!(doc)
    inject_editor_styles!(doc)
    inject_editor_runtime!(doc)
    doc.to_html
  end

  def serve_asset(path)
    rel = path.to_s.sub(%r{\A/+}, '')
    return nil if rel.blank? || rel.include?('..')

    abs = @site_root.join(rel).cleanpath
    return nil unless abs.to_s.start_with?(@site_root.to_s)
    return nil unless File.file?(abs)

    abs
  end

  def update_text!(path:, text_index:, value:)
    abs = resolve_html_path(path)
    raise ArgumentError, 'Page not found.' if abs.nil?

    if text_index.to_s.start_with?('review:')
      update_dynamic_review!(abs: abs, token: text_index.to_s, value: value)
      return
    end

    doc = Nokogiri::HTML(File.read(abs))
    node = editable_text_nodes(doc)[text_index.to_i]
    raise ArgumentError, 'Editable text not found.' if node.nil?

    node.content = value.to_s[0, 5000]
    write_html!(abs, doc)
  end

  def reorder_items!(path:, container_index:, old_index:, new_index:)
    abs = resolve_html_path(path)
    raise ArgumentError, 'Page not found.' if abs.nil?

    doc = Nokogiri::HTML(File.read(abs))
    group = reorder_groups(doc)[container_index.to_i]
    raise ArgumentError, 'Reorder group not found.' if group.nil?

    children = reorder_children(group)
    moved = children[old_index.to_i]
    target = children[new_index.to_i]
    raise ArgumentError, 'Reorder item not found.' if moved.nil? || target.nil?

    moved.remove
    if old_index.to_i < new_index.to_i
      target.after(moved)
    else
      target.before(moved)
    end

    write_html!(abs, doc)
  end

  private

  def resolve_html_path(path)
    raw = path.to_s.strip
    raw = '/' if raw.blank?
    rel = raw.sub(%r{\A/+}, '')

    candidates =
      if raw == '/' || rel.blank?
        ['index.html']
      elsif rel.end_with?('.html')
        [rel]
      else
        ["#{rel}.html", File.join(rel, 'index.html')]
      end

    candidates.each do |candidate|
      next if candidate.include?('..')

      abs = @site_root.join(candidate).cleanpath
      next unless abs.to_s.start_with?(@site_root.to_s)
      return abs if File.file?(abs)
    end

    nil
  end

  def page_title(abs, rel)
    doc = Nokogiri::HTML(File.read(abs))
    doc.at('title')&.text&.strip.presence || rel
  rescue StandardError
    rel
  end

  def editable_text_nodes(doc)
    candidates = doc.css(TEXT_SELECTOR).select do |node|
      next false if ignored_node?(node)
      next false if node.text.to_s.strip.blank?

      meaningful_text_node?(node)
    end

    candidates.reject do |node|
      candidates.any? { |other| other != node && node.ancestors.include?(other) && same_text_content?(node, other) }
    end
  end

  def mark_text_nodes!(doc)
    editable_text_nodes(doc).each_with_index do |node, index|
      node['data-xbolt-editable'] = 'true'
      node['data-xbolt-text-index'] = index.to_s
    end
  end

  def reorder_groups(doc)
    candidates = doc.css('div,ul,ol,section,main').select do |node|
      next false if ignored_node?(node)

      children = reorder_children(node)
      next false if children.size < 2
      next false if children.any? { |child| child['data-xbolt-items'].present? }
      next false if node.css('[data-xbolt-items]').any?

      class_name = node['class'].to_s.downcase
      child_classes = children.map { |child| child['class'].to_s.downcase }
      hinted_children = child_classes.count { |klass| klass.match?(ITEM_HINT) }

      hinted_children >= 2 ||
        (class_name.match?(GROUP_HINT) && repeated_children?(children)) ||
        repeated_card_like_children?(children)
    end

    candidates.reject do |node|
      candidates.any? { |other| other != node && other.ancestors.include?(node) }
    end
  end

  def reorder_children(node)
    node.element_children.reject { |child| NON_CONTENT_TAGS.include?(child.name) || child.text.to_s.strip.blank? }
  end

  def mark_reorder_groups!(doc)
    reorder_groups(doc).each_with_index do |node, group_index|
      node['data-xbolt-items'] = 'true'
      node['data-xbolt-container-index'] = group_index.to_s
      reorder_children(node).each_with_index do |child, child_index|
        child['data-xbolt-item'] = 'true'
        child['data-xbolt-item-index'] = child_index.to_s
      end
    end
  end

  def rewrite_asset_urls!(doc)
    doc.css('[href], [src], [poster]').each do |node|
      ASSET_ATTRS.each do |attr|
        raw = node[attr].to_s
        next if raw.blank? || raw.start_with?('#', 'mailto:', 'tel:', 'http://', 'https://', '//', 'data:')

        clean = raw.sub(%r{\A/+}, '')
        node[attr] = "/dashboard/website/static/#{clean}"
      end
    end
  end

  def inject_editor_styles!(doc)
    style = Nokogiri::XML::Node.new('style', doc)
    style['data-xbolt-static-editor'] = 'true'
    style.content = <<~CSS
      [data-xbolt-editable]{outline:2px solid transparent;outline-offset:4px;border-radius:8px;cursor:pointer;transition:outline-color .15s,background .15s}
      [data-xbolt-editable]:hover{outline-color:#f59e0b;background:rgba(245,158,11,.10)}
      [data-xbolt-selected]{outline-color:#f59e0b!important;background:rgba(245,158,11,.16)!important}
      [data-xbolt-items]{min-height:24px;outline:1px dashed rgba(245,158,11,.25);outline-offset:8px}
      [data-xbolt-item]{cursor:grab;transition:box-shadow .15s,transform .15s}
      [data-xbolt-item]:hover{box-shadow:0 0 0 2px rgba(245,158,11,.55);transform:translateY(-1px)}
      .xbolt-drag-ghost{opacity:.45}
    CSS
    (doc.at('head') || doc.root).add_child(style)
  end

  def inject_editor_runtime!(doc)
    script = Nokogiri::XML::Node.new('script', doc)
    script['data-xbolt-static-editor-runtime'] = 'true'
    script.content = <<~JS
      (function () {
        function markReviewCards() {
          var cards = Array.prototype.slice.call(document.querySelectorAll("#reviews-grid .review-card"));
          cards.forEach(function (card, index) {
            card.setAttribute("data-xbolt-item", "true");
            card.setAttribute("data-xbolt-item-index", String(index));

            var name = card.querySelector("div[style*='Playfair Display']");
            var service = card.querySelector("div[style*='text-transform:uppercase']");
            var body = card.querySelector("p");

            if (name) {
              name.setAttribute("data-xbolt-editable", "true");
              name.setAttribute("data-xbolt-text-index", "review:" + index + ":name");
            }
            if (service) {
              service.setAttribute("data-xbolt-editable", "true");
              service.setAttribute("data-xbolt-text-index", "review:" + index + ":service");
            }
            if (body) {
              body.setAttribute("data-xbolt-editable", "true");
              body.setAttribute("data-xbolt-text-index", "review:" + index + ":reviewText");
            }
          });

          var grid = document.getElementById("reviews-grid");
          if (grid && cards.length > 1) {
            grid.setAttribute("data-xbolt-items", "true");
            grid.setAttribute("data-xbolt-container-index", "dynamic-reviews");
          }
        }

        if (document.readyState === "loading") {
          document.addEventListener("DOMContentLoaded", function () { setTimeout(markReviewCards, 50); });
        } else {
          setTimeout(markReviewCards, 50);
        }
      })();
    JS
    (doc.at('body') || doc.root).add_child(script)
  end

  def ignored_node?(node)
    NON_CONTENT_TAGS.include?(node.name) ||
      node.ancestors.any? { |ancestor| NON_CONTENT_TAGS.include?(ancestor.name) } ||
      node['aria-hidden'].to_s == 'true' ||
      node['hidden'].present?
  end

  def meaningful_text_node?(node)
    own_text = node.children.select(&:text?).map(&:text).join.strip
    return true if own_text.present? && node.element_children.none? { |child| child.text.to_s.strip.present? }

    text_children = node.element_children.reject { |child| ignored_node?(child) || child.text.to_s.strip.blank? }
    return true if text_children.empty?

    false
  end

  def same_text_content?(left, right)
    left.text.to_s.squish == right.text.to_s.squish
  end

  def repeated_children?(children)
    signatures = children.map { |child| child_signature(child) }
    signatures.tally.values.any? { |count| count >= 2 }
  end

  def repeated_card_like_children?(children)
    children.count { |child| child.css('h1,h2,h3,h4,h5,h6,p,blockquote,span,small').size >= 2 } >= 2 &&
      repeated_children?(children)
  end

  def child_signature(child)
    classes = child['class'].to_s.split.select { |klass| klass.match?(ITEM_HINT) }.sort
    [child.name, classes.first(4)].join(':')
  end

  def update_dynamic_review!(abs:, token:, value:)
    _prefix, raw_index, field = token.split(':', 3)
    index = raw_index.to_i
    raise ArgumentError, 'Review field not found.' unless %w[name service reviewText].include?(field)

    html = File.read(abs)
    pattern = /\{\s*name:\s*"((?:\\.|[^"])*)",\s*reviewText:\s*"((?:\\.|[^"])*)",\s*service:\s*"((?:\\.|[^"])*)"\s*\}/m
    current = -1
    changed = html.sub(pattern) do |match|
      current += 1
      next match unless current == index

      name = Regexp.last_match(1)
      review_text = Regexp.last_match(2)
      service = Regexp.last_match(3)

      case field
      when 'name' then name = js_string_escape(value.to_s[0, 5000])
      when 'reviewText' then review_text = js_string_escape(value.to_s[0, 5000])
      when 'service' then service = js_string_escape(value.to_s[0, 5000])
      end

      %({ name: "#{name}", reviewText: "#{review_text}", service: "#{service}" })
    end

    raise ArgumentError, 'Review not found.' if changed == html

    backup = "#{abs}.xbolt-backup"
    FileUtils.cp(abs, backup) unless File.exist?(backup)
    File.write(abs, changed)
    refresh_sitemap!
  end

  def js_string_escape(value)
    JSON.generate(value)[1...-1]
  end

  def write_html!(abs, doc)
    backup = "#{abs}.xbolt-backup"
    FileUtils.cp(abs, backup) unless File.exist?(backup)
    File.write(abs, doc.to_html)
    refresh_sitemap!
  end

  def refresh_sitemap!
    TenantSitemapInstaller.new(business: @business).install!
  rescue StandardError => e
    Rails.logger.warn("Tenant sitemap refresh failed for business=#{@business&.id}: #{e.class}: #{e.message}")
  end
end
