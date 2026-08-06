require "nokogiri"
require "fileutils"

class TenantStaticSiteEditor
  TEXT_SELECTOR = "h1,h2,h3,h4,h5,h6,p,a,button,span,li,blockquote,strong,em,b,i,small,label,figcaption,cite,div,td,th".freeze
  NON_CONTENT_TAGS = %w[script style noscript svg path img picture video audio source canvas iframe input textarea select option br hr].freeze
  GROUP_HINT = /grid|cards?|reviews?|testimonials?|gallery|work|projects?|services?|features?|team|pricing|plans?|portfolio|case|results?|logos?|columns?|row|list|slider|carousel/i
  # Match real card tokens (review-card, service-card) — not labels like review-name / review-service.
  ITEM_HINT = /(?:^|\s)([\w-]*card|testimonial|gallery-item|portfolio-item|team-member|slide|logo)(?:\s|$)/i
  ASSET_ATTRS = %w[href src poster].freeze
  MAX_TEXT_LENGTH = 5000
  EVENT_HANDLER_ATTRS = /\Aon/i

  def initialize(business:)
    @business = business
    @site_root = Rails.root.join("public", "tenant_sites", @business.subdomain.to_s)
  end

  def deployed?
    File.file?(@site_root.join("index.html"))
  end

  def pages
    return [] unless Dir.exist?(@site_root)

    Dir.glob(@site_root.join("**", "*.html")).filter_map do |abs|
      rel = Pathname.new(abs).relative_path_from(@site_root).to_s.tr("\\", "/")
      {
        path: rel == "index.html" ? "/" : "/#{rel.delete_suffix('/index.html').delete_suffix('.html')}",
        file: rel,
        title: page_title(abs, rel)
      }
    end.sort_by { |page| page[:path] == "/" ? "" : page[:path] }
  end

  def render_editor_html(path:)
    abs = resolve_html_path(path)
    raise ArgumentError, "Page not found." if abs.nil?

    doc = Nokogiri::HTML(File.read(abs))
    neutralize_scripts!(doc)
    rewrite_asset_urls!(doc)
    mark_text_nodes!(doc)
    mark_reorder_groups!(doc)
    inject_editor_styles!(doc)
    inject_editor_runtime!(doc)
    doc.to_html
  end

  def serve_asset(path)
    rel = path.to_s.sub(%r{\A/+}, "")
    return nil if rel.blank? || rel.include?("..")

    abs = @site_root.join(rel).cleanpath
    return nil unless abs.to_s.start_with?(@site_root.to_s)
    return nil unless File.file?(abs)

    abs
  end

  def update_text!(path:, text_index:, value:)
    abs = resolve_html_path(path)
    raise ArgumentError, "Page not found." if abs.nil?

    text = value.to_s
    raise ArgumentError, "Text is too long." if text.bytesize > MAX_TEXT_LENGTH

    if text_index.to_s.start_with?("review:")
      update_dynamic_review!(abs: abs, token: text_index.to_s, value: text)
      return
    end

    doc = Nokogiri::HTML(File.read(abs))
    node = editable_text_nodes(doc)[text_index.to_i]
    raise ArgumentError, "Editable text not found." if node.nil?

    node.content = text[0, MAX_TEXT_LENGTH]
    write_html!(abs, doc)
  end

  def reorder_items!(path:, container_index:, old_index:, new_index:)
    abs = resolve_html_path(path)
    raise ArgumentError, "Page not found." if abs.nil?

    doc = Nokogiri::HTML(File.read(abs))
    group = reorder_groups(doc)[container_index.to_i]
    raise ArgumentError, "Reorder group not found." if group.nil?

    children = reorder_children(group)
    moved = children[old_index.to_i]
    target = children[new_index.to_i]
    raise ArgumentError, "Reorder item not found." if moved.nil? || target.nil?

    moved.remove
    if old_index.to_i < new_index.to_i
      target.after(moved)
    else
      target.before(moved)
    end

    write_html!(abs, doc)
  end

  def duplicate_item!(path:, container_index:, item_index:)
    if container_index.to_s == "dynamic-reviews"
      return duplicate_dynamic_review!(path: path, item_index: item_index)
    end

    abs = resolve_html_path(path)
    raise ArgumentError, "Page not found." if abs.nil?

    doc = Nokogiri::HTML(File.read(abs))
    group = reorder_groups(doc)[container_index.to_i]
    raise ArgumentError, "Card group not found." if group.nil?

    children = reorder_children(group)
    source = children[item_index.to_i]
    raise ArgumentError, "Card not found." if source.nil?
    raise ArgumentError, "Too many cards in this group." if children.size >= 40

    expected = children.size + 1
    clone = source.dup
    annotate_duplicated_text!(clone)
    source.add_next_sibling(clone)
    write_html!(abs, doc)

    verify_count = item_count_on_disk(abs, container_index)
    raise ArgumentError, "Duplicate did not persist." if verify_count < expected

    { ok: true, item_count: verify_count, container_index: container_index.to_i }
  end

  def delete_item!(path:, container_index:, item_index:)
    if container_index.to_s == "dynamic-reviews"
      return delete_dynamic_review!(path: path, item_index: item_index)
    end

    abs = resolve_html_path(path)
    raise ArgumentError, "Page not found." if abs.nil?

    doc = Nokogiri::HTML(File.read(abs))
    group = reorder_groups(doc)[container_index.to_i]
    raise ArgumentError, "Card group not found." if group.nil?

    children = reorder_children(group)
    raise ArgumentError, "Keep at least one card in this group." if children.size <= 1

    target = children[item_index.to_i]
    raise ArgumentError, "Card not found." if target.nil?

    expected = children.size - 1
    target.remove
    write_html!(abs, doc)

    verify_count = item_count_on_disk(abs, container_index)
    raise ArgumentError, "Delete did not persist." if verify_count != expected

    { ok: true, item_count: verify_count, container_index: container_index.to_i }
  end

  private

  def resolve_html_path(path)
    raw = path.to_s.strip
    raw = "/" if raw.blank?
    rel = raw.sub(%r{\A/+}, "")

    candidates =
      if raw == "/" || rel.blank?
        ["index.html"]
      elsif rel.end_with?(".html")
        [rel]
      else
        ["#{rel}.html", File.join(rel, "index.html")]
      end

    candidates.each do |candidate|
      next if candidate.include?("..")

      abs = @site_root.join(candidate).cleanpath
      next unless abs.to_s.start_with?(@site_root.to_s)
      return abs if File.file?(abs)
    end

    nil
  end

  def page_title(abs, rel)
    doc = Nokogiri::HTML(File.read(abs))
    doc.at("title")&.text&.strip.presence || rel
  rescue StandardError
    rel
  end

  # Keep styling/runtime scripts (e.g. Tailwind CDN) so the live site looks correct.
  # Only strip clearly dangerous vectors; preview runs sandboxed in an iframe.
  def neutralize_scripts!(doc)
    doc.css("iframe, object, embed").remove

    doc.traverse do |node|
      next unless node.element?

      node.attribute_nodes.each do |attr|
        name = attr.name.to_s
        value = attr.value.to_s

        if name.match?(EVENT_HANDLER_ATTRS)
          attr.remove
          next
        end

        if %w[href src action formaction].include?(name.downcase) && value.strip.downcase.start_with?("javascript:")
          attr.remove
        end
      end
    end
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
      node["data-xbolt-editable"] = "true"
      node["data-xbolt-text-index"] = index.to_s
    end
  end

  def reorder_groups(doc)
    candidates = doc.css("div,ul,ol,section,main").select do |node|
      next false if ignored_node?(node)

      children = reorder_children(node)
      next false if children.size < 2
      next false if children.any? { |child| child["data-xbolt-items"].present? }
      next false if node.css("[data-xbolt-items]").any?

      class_name = node["class"].to_s.downcase
      id_name = node["id"].to_s.downcase
      hinted_children = children.count { |child| item_like_child?(child) }

      id_name == "reviews-grid" ||
        hinted_children >= 2 ||
        ((class_name.match?(GROUP_HINT) || id_name.match?(GROUP_HINT)) && repeated_children?(children)) ||
        repeated_card_like_children?(children)
    end

    candidates.reject do |node|
      candidates.any? { |other| other != node && other.ancestors.include?(node) }
    end
  end

  def reorder_children(node)
    node.element_children.reject { |child| NON_CONTENT_TAGS.include?(child.name) || child.text.to_s.strip.blank? }
  end

  def item_like_child?(child)
    return true if %w[article li].include?(child.name)

    child["class"].to_s.downcase.match?(ITEM_HINT)
  end

  def mark_reorder_groups!(doc)
    reorder_groups(doc).each_with_index do |node, group_index|
      node["data-xbolt-items"] = "true"
      node["data-xbolt-container-index"] = group_index.to_s
      reorder_children(node).each_with_index do |child, child_index|
        child["data-xbolt-item"] = "true"
        child["data-xbolt-item-index"] = child_index.to_s
      end
    end
  end

  def rewrite_asset_urls!(doc)
    doc.css("[href], [src], [poster]").each do |node|
      ASSET_ATTRS.each do |attr|
        raw = node[attr].to_s
        next if raw.blank? || raw.start_with?("#", "mailto:", "tel:", "http://", "https://", "//", "data:")

        # Root-absolute paths like /logo.png and relative ./assets/... both map
        # into the tenant site folder via the static asset proxy.
        clean = raw.sub(%r{\A\./}, "").sub(%r{\A/+}, "")
        next if clean.blank? || clean.include?("..")

        # Keep HTML page links navigable in the editor (do not send them through the asset proxy).
        if attr == "href" && html_page_href?(clean)
          page_path = normalize_editor_page_path(clean)
          node["data-xbolt-page"] = page_path
          node[attr] = "#xbolt-page:#{page_path}"
          next
        end

        node[attr] = asset_proxy_path(clean)
      end
    end

    # Rewrite url(...) references inside <style> blocks when they are relative.
    doc.css("style").each do |style_node|
      css = style_node.content.to_s
      rewritten = css.gsub(/url\(\s*(['"]?)(?!https?:|data:|\/\/|#)([^'")]+)\1\s*\)/i) do
        quote = Regexp.last_match(1)
        path = Regexp.last_match(2).to_s.strip.sub(%r{\A\./}, "").sub(%r{\A/+}, "")
        next Regexp.last_match(0) if path.blank? || path.include?("..") || path.downcase.end_with?(".html")

        "url(#{quote}#{asset_proxy_path(path)}#{quote})"
      end
      style_node.content = rewritten
    end
  end

  def html_page_href?(path)
    rel = path.to_s.downcase
    return true if rel.end_with?(".html", ".htm")
    return true if rel.blank? || rel == "index" || rel == "index.html"

    # Extensionless paths that match a deployed page (e.g. "about", "services/work")
    pages.any? { |page| page[:path] == normalize_editor_page_path(path) }
  end

  def normalize_editor_page_path(path)
    rel = path.to_s.sub(%r{\A\./}, "").sub(%r{\A/+}, "")
    rel = rel.sub(%r{/index\.html?\z}i, "")
    rel = rel.sub(%r{\.html?\z}i, "")
    rel = "" if rel.casecmp("index").zero?
    rel.present? ? "/#{rel}" : "/"
  end

  def asset_proxy_path(relative_path)
    "/dashboard/website/static/assets/#{relative_path}"
  end

  def inject_editor_styles!(doc)
    style = Nokogiri::XML::Node.new("style", doc)
    style["data-xbolt-static-editor"] = "true"
    # Outline/ring only — never paint fills that change tenant text/background colors.
    style.content = <<~CSS
      [data-xbolt-editable]{
        outline:2px solid transparent;
        outline-offset:3px;
        border-radius:6px;
        cursor:text;
        transition:outline-color .15s ease, box-shadow .15s ease;
      }
      [data-xbolt-editable]:hover{
        outline-color:rgba(245,158,11,.85);
        box-shadow:0 0 0 3px rgba(245,158,11,.14);
      }
      [data-xbolt-selected]{
        outline:2px solid #f59e0b !important;
        outline-offset:3px !important;
        box-shadow:0 0 0 4px rgba(245,158,11,.18) !important;
      }
      [data-xbolt-items]{
        min-height:24px;
        outline:1px dashed rgba(245,158,11,.25);
        outline-offset:10px;
        border-radius:12px;
      }
      [data-xbolt-item]{
        cursor:grab;
        transition:box-shadow .15s ease;
        position:relative;
      }
      [data-xbolt-item]:hover{ box-shadow:0 0 0 2px rgba(245,158,11,.5); }
      [data-xbolt-item-selected]{ box-shadow:0 0 0 2px #f59e0b !important; }
      .xbolt-drag-ghost{opacity:.45}
    CSS
    (doc.at("head") || doc.root).add_child(style)
  end

  def inject_editor_runtime!(doc)
    # Static review cards are edited as normal HTML. Legacy JS-rendered grids still get marked.
    script = Nokogiri::XML::Node.new("script", doc)
    script["data-xbolt-static-editor-runtime"] = "true"
    script.content = <<~JS
      (function () {
        var grid = document.getElementById("reviews-grid");
        if (!grid) return;

        var staticCards = grid.querySelectorAll(".review-card");
        if (staticCards.length) {
          // Show every card in the editor (ignore production load-more hiding).
          Array.prototype.forEach.call(staticCards, function (card) { card.style.display = ""; });
          var moreBtn = document.getElementById("load-more-reviews");
          if (moreBtn) moreBtn.style.display = "none";
          return;
        }

        function markReviews() {
          var cards = Array.prototype.slice.call(grid.querySelectorAll(".review-card"));
          cards.forEach(function (card, index) {
            card.setAttribute("data-xbolt-item", "true");
            card.setAttribute("data-xbolt-item-index", String(index));
            var name = card.querySelector(".review-name") ||
              card.querySelector("div[style*='letter-spacing:0.5px']") ||
              card.querySelector("div[style*='letter-spacing: 0.5px']");
            var service = card.querySelector(".review-service") ||
              card.querySelector("div[style*='text-transform:uppercase']");
            var body = card.querySelector("p.review-text, p");
            if (name) { name.setAttribute("data-xbolt-editable", "true"); name.setAttribute("data-xbolt-text-index", "review:" + index + ":name"); }
            if (service) { service.setAttribute("data-xbolt-editable", "true"); service.setAttribute("data-xbolt-text-index", "review:" + index + ":service"); }
            if (body) { body.setAttribute("data-xbolt-editable", "true"); body.setAttribute("data-xbolt-text-index", "review:" + index + ":reviewText"); }
          });
          if (cards.length > 1) {
            grid.setAttribute("data-xbolt-items", "true");
            grid.setAttribute("data-xbolt-container-index", "dynamic-reviews");
          }
        }

        markReviews();
        if (typeof MutationObserver === "undefined") return;
        var timer = null;
        var observer = new MutationObserver(function () {
          if (timer) clearTimeout(timer);
          timer = setTimeout(markReviews, 40);
        });
        observer.observe(grid, { childList: true, subtree: true });
      })();
    JS
    (doc.at("body") || doc.root).add_child(script)
  end

  def ignored_node?(node)
    NON_CONTENT_TAGS.include?(node.name) ||
      node.ancestors.any? { |ancestor| NON_CONTENT_TAGS.include?(ancestor.name) } ||
      node["aria-hidden"].to_s == "true" ||
      node["hidden"].present?
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
    children.count { |child| child.css("h1,h2,h3,h4,h5,h6,p,blockquote,span,small").size >= 2 } >= 2 &&
      repeated_children?(children)
  end

  def child_signature(child)
    classes = child["class"].to_s.split.select { |klass| klass.match?(ITEM_HINT) }.sort
    [child.name, classes.first(4)].join(":")
  end

  def update_dynamic_review!(abs:, token:, value:)
    _prefix, raw_index, field = token.split(":", 3)
    index = raw_index.to_i
    raise ArgumentError, "Review field not found." unless %w[name service reviewText].include?(field)

    html = File.read(abs)
    pattern = review_object_pattern
    current = -1
    replaced = false
    # gsub — String#sub only ever rewrites the first match, so index > 0 always failed.
    changed = html.gsub(pattern) do |match|
      current += 1
      next match unless current == index

      name = Regexp.last_match(1)
      review_text = Regexp.last_match(2)
      service = Regexp.last_match(3)

      case field
      when "name" then name = js_string_escape(value.to_s[0, MAX_TEXT_LENGTH])
      when "reviewText" then review_text = js_string_escape(value.to_s[0, MAX_TEXT_LENGTH])
      when "service" then service = js_string_escape(value.to_s[0, MAX_TEXT_LENGTH])
      end

      replaced = true
      %({ name: "#{name}", reviewText: "#{review_text}", service: "#{service}" })
    end

    raise ArgumentError, "Review not found." unless replaced
    write_raw_html!(abs, changed)
  end

  def duplicate_dynamic_review!(path:, item_index:)
    abs = resolve_html_path(path)
    raise ArgumentError, "Page not found." if abs.nil?

    html = File.read(abs)
    matches = review_matches(html)
    raise ArgumentError, "Review not found." if matches.empty?

    index = item_index.to_i
    source = matches[index]
    raise ArgumentError, "Review not found." if source.nil?
    raise ArgumentError, "Too many reviews." if matches.size >= 40

    clone = %({ name: "#{source[:name]} (copy)", reviewText: "#{source[:review_text]}", service: "#{source[:service]}" })
    changed = html.dup
    changed.insert(source[:end], ",\n      #{clone}")
    write_raw_html!(abs, changed)

    count = review_matches(File.read(abs)).size
    raise ArgumentError, "Duplicate did not persist." if count <= matches.size

    { ok: true, item_count: count, container_index: "dynamic-reviews" }
  end

  def delete_dynamic_review!(path:, item_index:)
    abs = resolve_html_path(path)
    raise ArgumentError, "Page not found." if abs.nil?

    html = File.read(abs)
    matches = review_matches(html)
    raise ArgumentError, "Keep at least one review." if matches.size <= 1

    index = item_index.to_i
    target = matches[index]
    raise ArgumentError, "Review not found." if target.nil?

    before = html[0...target[:begin]]
    after = html[target[:end]..]
    if before.match?(/,\s*\z/)
      before = before.sub(/,\s*\z/, "")
    elsif after.match?(/\A\s*,/)
      after = after.sub(/\A\s*,/, "")
    end

    write_raw_html!(abs, before + after)

    count = review_matches(File.read(abs)).size
    raise ArgumentError, "Delete did not persist." if count != matches.size - 1

    { ok: true, item_count: count, container_index: "dynamic-reviews" }
  end

  def item_count_on_disk(abs, container_index)
    doc = Nokogiri::HTML(File.read(abs))
    group = reorder_groups(doc)[container_index.to_i]
    return 0 if group.nil?

    reorder_children(group).size
  end

  def review_object_pattern
    /\{\s*name:\s*"((?:\\.|[^"])*)",\s*reviewText:\s*"((?:\\.|[^"])*)",\s*service:\s*"((?:\\.|[^"])*)"\s*\}/m
  end

  def review_matches(html)
    matches = []
    html.scan(review_object_pattern) do
      m = Regexp.last_match
      matches << {
        name: m[1],
        review_text: m[2],
        service: m[3],
        begin: m.begin(0),
        end: m.end(0)
      }
    end
    matches
  end

  def annotate_duplicated_text!(node)
    heading = node.at_css(".review-name, h1, h2, h3, h4, h5, h6, p, span, strong")
    return if heading.nil?

    text = heading.text.to_s.strip
    return if text.blank?

    heading.content = text.end_with?("(copy)") ? text : "#{text} (copy)"

    avatar = node.at_css(".review-avatar")
    return if avatar.nil?

    initial = heading.text.to_s.strip[0].to_s.upcase
    avatar.content = initial if initial.present?
  end

  def js_string_escape(value)
    JSON.generate(value)[1...-1]
  end

  def write_raw_html!(abs, html)
    backup = "#{abs}.xbolt-backup"
    FileUtils.cp(abs, backup) unless File.exist?(backup)
    atomic_write!(abs, html)
    refresh_sitemap!
  end

  def write_html!(abs, doc)
    backup = "#{abs}.xbolt-backup"
    FileUtils.cp(abs, backup) unless File.exist?(backup)
    atomic_write!(abs, doc.to_html)
    refresh_sitemap!
  end

  def atomic_write!(abs, contents)
    # Write + fsync so a follow-up preview read cannot race a buffered old file.
    File.open(abs, "w") do |file|
      file.write(contents)
      file.flush
      file.fsync
    end
  end

  def refresh_sitemap!
    TenantSitemapInstaller.new(business: @business).install!
  rescue StandardError => e
    Rails.logger.warn("Tenant sitemap refresh failed for business=#{@business&.id}: #{e.class}: #{e.message}")
  end
end
