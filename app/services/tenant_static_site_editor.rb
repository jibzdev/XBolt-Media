require "nokogiri"
require "fileutils"
require "securerandom"

class TenantStaticSiteEditor
  ASSET_ATTRS = %w[href src poster].freeze
  EVENT_HANDLER_ATTRS = /\Aon/i
  MAX_TEXT_LENGTH = 20_000
  MAX_HTML_BYTES = 2.megabytes
  MAX_CSS_BYTES = 1.megabyte
  MAX_IMAGE_BYTES = 5.megabytes
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/png image/webp image/gif image/svg+xml].freeze
  BACKUP_KEEP = 30
  EDITOR_SKIP = "[data-xbolt-static-editor],[data-xbolt-static-editor-runtime],[data-xbolt-editor-chrome]".freeze

  STYLE_PROPS = %w[
    color background-color background-image font-size font-weight font-family text-align
    margin padding display gap opacity border-radius border
    line-height letter-spacing width max-width height max-height
    flex-direction justify-content align-items grid-template-columns
  ].freeze

  def initialize(business:)
    @business = business
    @site_root = Rails.root.join("public", "tenant_sites", @business.subdomain.to_s)
    @backup_root = Rails.root.join("public", "tenant_sites_backups", @business.subdomain.to_s, "editor")
    @redo_root = Rails.root.join("public", "tenant_sites_backups", @business.subdomain.to_s, "editor_redo")
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
    inject_editor_styles!(doc)
    inject_editor_runtime!(doc)
    doc.to_html
  end

  def page_source(path:)
    abs = resolve_html_path(path)
    raise ArgumentError, "Page not found." if abs.nil?

    html = File.read(abs)
    doc = Nokogiri::HTML(html)
    css_sources = []

    doc.css("style").each_with_index do |style_node, index|
      next if style_node["data-xbolt-static-editor"].present?

      css_sources << {
        id: "style:#{index}",
        kind: "inline",
        label: "Inline <style> ##{index + 1}",
        content: style_node.content.to_s
      }
    end

    doc.css('link[rel="stylesheet"][href]').each_with_index do |link, index|
      href = link["href"].to_s
      next if href.start_with?("http://", "https://", "//", "data:")

      rel = href.sub(%r{\A\./}, "").sub(%r{\A/+}, "")
      next if rel.blank? || rel.include?("..")

      css_abs = @site_root.join(rel).cleanpath
      next unless css_abs.to_s.start_with?(@site_root.to_s) && File.file?(css_abs)

      css_sources << {
        id: "file:#{rel}",
        kind: "file",
        label: rel,
        path: rel,
        content: File.read(css_abs)
      }
    end

    {
      path: path.to_s,
      file: abs.relative_path_from(@site_root).to_s.tr("\\", "/"),
      html: html,
      css_sources: css_sources,
      can_undo: can_undo?,
      can_redo: can_redo?
    }
  end

  def serve_asset(path)
    rel = path.to_s.sub(%r{\A/+}, "").split("?", 2).first.to_s
    return nil if rel.blank? || rel.include?("..")

    abs = @site_root.join(rel).cleanpath
    return nil unless abs.to_s.start_with?(@site_root.to_s)
    return nil unless File.file?(abs)

    abs
  end

  # --- Path-based ops -------------------------------------------------------

  def update_text_at_path!(path:, element_path:, value:)
    text = value.to_s
    raise ArgumentError, "Text is too long." if text.bytesize > MAX_TEXT_LENGTH

    mutate_html_path!(path, element_path) do |node|
      node.content = text[0, MAX_TEXT_LENGTH]
    end
  end

  def update_styles_at_path!(path:, element_path:, styles:)
    raise ArgumentError, "Styles required." unless styles.is_a?(Hash) || styles.is_a?(ActionController::Parameters)

    mutate_html_path!(path, element_path) do |node|
      current = parse_inline_style(node["style"].to_s)
      styles.to_h.each do |key, raw|
        prop = key.to_s.downcase.tr("_", "-")
        next unless STYLE_PROPS.include?(prop)

        val = raw.to_s.strip
        if val.blank?
          current.delete(prop)
        else
          raise ArgumentError, "Invalid style value." if val.match?(/[;{}<>]|expression|javascript:/i)

          current[prop] = val[0, 200]
        end
      end
      node["style"] = current.map { |k, v| "#{k}: #{v}" }.join("; ")
      node.remove_attribute("style") if node["style"].blank?
    end
  end

  def update_attrs_at_path!(path:, element_path:, attrs:)
    raise ArgumentError, "Attributes required." unless attrs.is_a?(Hash) || attrs.is_a?(ActionController::Parameters)

    allowed = %w[href src alt title class id]
    mutate_html_path!(path, element_path) do |node|
      attrs.to_h.each do |key, raw|
        name = key.to_s.downcase
        next unless allowed.include?(name)
        next if name.match?(EVENT_HANDLER_ATTRS)

        val = raw.to_s.strip
        if val.blank?
          node.remove_attribute(name)
        else
          raise ArgumentError, "Invalid attribute value." if val.match?(/javascript:/i)

          val = demangle_editor_href(val) if name == "href"
          val = demangle_editor_src(val) if name == "src"
          node[name] = val[0, 2000]
        end
      end
    end
  end

  def replace_outer_html_at_path!(path:, element_path:, html:)
    fragment = html.to_s
    raise ArgumentError, "HTML is empty." if fragment.blank?
    raise ArgumentError, "HTML is too large." if fragment.bytesize > MAX_HTML_BYTES

    mutate_html_path!(path, element_path) do |node|
      parsed = Nokogiri::HTML::DocumentFragment.parse(fragment)
      raise ArgumentError, "Could not parse HTML." if parsed.children.blank?

      replacement = parsed.children.find(&:element?) || parsed.children.first
      raise ArgumentError, "Could not parse HTML." if replacement.nil?

      node.replace(replacement)
    end
  end

  def duplicate_at_path!(path:, element_path:)
    mutate_html_path!(path, element_path) do |node|
      raise ArgumentError, "Cannot duplicate the root element." if %w[html body head].include?(node.name)

      clone = node.dup
      annotate_copy_label!(clone)
      node.add_next_sibling(clone)
    end
  end

  def delete_at_path!(path:, element_path:)
    mutate_html_path!(path, element_path) do |node|
      raise ArgumentError, "Cannot delete the root element." if %w[html body head].include?(node.name)

      node.remove
    end
  end

  def move_at_path!(path:, element_path:, direction:)
    dir = direction.to_s
    raise ArgumentError, "Direction must be up or down." unless %w[up down].include?(dir)

    mutate_html_path!(path, element_path) do |node|
      raise ArgumentError, "Cannot move the root element." if %w[html body head].include?(node.name)

      if dir == "up"
        prev = node.previous_element
        raise ArgumentError, "Already at the top." if prev.nil?

        prev.add_previous_sibling(node)
      else
        nxt = node.next_element
        raise ArgumentError, "Already at the bottom." if nxt.nil?

        nxt.add_next_sibling(node)
      end
    end
  end

  def wrap_at_path!(path:, element_path:, tag: "div")
    tag_name = tag.to_s.downcase
    raise ArgumentError, "Invalid wrap tag." unless %w[div section article aside].include?(tag_name)

    mutate_html_path!(path, element_path) do |node|
      raise ArgumentError, "Cannot wrap the root element." if %w[html body head].include?(node.name)

      wrapper = Nokogiri::XML::Node.new(tag_name, node.document)
      node.add_next_sibling(wrapper)
      wrapper.add_child(node)
    end
  end

  def replace_image_at_path!(path:, element_path:, src: nil, alt: nil, uploaded_file: nil)
    final_src = src.to_s.strip
    if uploaded_file.present?
      final_src = store_uploaded_image!(uploaded_file)
    else
      final_src = demangle_editor_src(final_src)
    end
    raise ArgumentError, "Image source required." if final_src.blank?
    raise ArgumentError, "Invalid image URL." if final_src.match?(/javascript:/i)

    mutate_html_path!(path, element_path) do |node|
      if node.name == "img"
        node["src"] = final_src
        node["alt"] = alt.to_s[0, 300] if !alt.nil?
      else
        styles = parse_inline_style(node["style"].to_s)
        styles["background-image"] = "url(#{final_src})"
        node["style"] = styles.map { |k, v| "#{k}: #{v}" }.join("; ")
      end
    end

    { ok: true, src: final_src }
  end

  def save_html!(path:, html:)
    abs = resolve_html_path(path)
    raise ArgumentError, "Page not found." if abs.nil?

    content = html.to_s
    raise ArgumentError, "HTML is empty." if content.blank?
    raise ArgumentError, "HTML is too large." if content.bytesize > MAX_HTML_BYTES
    raise ArgumentError, "HTML looks invalid." unless content.match?(/<html[\s>]|<!DOCTYPE/i) || content.include?("<body")

    versioned_backup!(abs)
    write_raw!(abs, content)
    refresh_sitemap!
    { ok: true }
  end

  def save_css!(path:, source_id:, css:)
    abs = resolve_html_path(path)
    raise ArgumentError, "Page not found." if abs.nil?

    content = css.to_s
    raise ArgumentError, "CSS is too large." if content.bytesize > MAX_CSS_BYTES
    raise ArgumentError, "CSS contains forbidden content." if content.match?(/expression\s*\(|javascript:/i)

    id = source_id.to_s
    if id.start_with?("style:")
      index = id.split(":", 2).last.to_i
      doc = Nokogiri::HTML(File.read(abs))
      styles = doc.css("style").reject { |n| n["data-xbolt-static-editor"].present? }
      node = styles[index]
      raise ArgumentError, "Style block not found." if node.nil?

      node.content = content
      versioned_backup!(abs)
      # Prefer preserving surrounding HTML: rewrite only the style text via raw replace when possible
      write_raw!(abs, doc.to_html)
      refresh_sitemap!
    elsif id.start_with?("file:")
      rel = id.delete_prefix("file:")
      raise ArgumentError, "Invalid CSS path." if rel.blank? || rel.include?("..")

      css_abs = @site_root.join(rel).cleanpath
      raise ArgumentError, "CSS file not found." unless css_abs.to_s.start_with?(@site_root.to_s) && File.file?(css_abs)

      versioned_backup!(css_abs)
      write_raw!(css_abs, content)
    else
      raise ArgumentError, "Unknown CSS source."
    end

    { ok: true }
  end

  def undo!(path: nil)
    latest = newest_backup(@backup_root)
    raise ArgumentError, "Nothing to undo." if latest.nil?

    abs = restore_target_from_backup!(latest)
    push_history_copy!(@redo_root, abs)
    FileUtils.cp(latest, abs)
    FileUtils.rm_f(latest)
    refresh_sitemap!
    {
      ok: true,
      restored_from: File.basename(latest),
      can_undo: can_undo?,
      can_redo: can_redo?
    }
  end

  def redo!(path: nil)
    latest = newest_backup(@redo_root)
    raise ArgumentError, "Nothing to redo." if latest.nil?

    abs = restore_target_from_backup!(latest)
    # Move current into undo stack without clearing redo (versioned_backup! clears redo)
    FileUtils.mkdir_p(@backup_root)
    stamp = Time.current.strftime("%Y%m%d-%H%M%S-%L")
    rel = Pathname.new(abs).relative_path_from(@site_root).to_s.tr("\\", "/")
    safe = rel.gsub("/", "__")
    FileUtils.cp(abs, @backup_root.join("#{stamp}__#{safe}"))
    FileUtils.cp(latest, abs)
    FileUtils.rm_f(latest)
    refresh_sitemap!
    {
      ok: true,
      restored_from: File.basename(latest),
      can_undo: can_undo?,
      can_redo: can_redo?
    }
  end

  def can_undo?(path: nil)
    newest_backup(@backup_root).present?
  end

  def can_redo?(path: nil)
    newest_backup(@redo_root).present?
  end

  private

  def mutate_html_path!(path, element_path)
    abs = resolve_html_path(path)
    raise ArgumentError, "Page not found." if abs.nil?

    doc = Nokogiri::HTML(File.read(abs))
    node = find_by_path!(doc, element_path)
    yield node
    versioned_backup!(abs)
    write_raw!(abs, doc.to_html)
    refresh_sitemap!
    { ok: true }
  end

  def find_by_path!(doc, element_path)
    path = element_path.to_s.strip
    raise ArgumentError, "Element path required." if path.blank?
    raise ArgumentError, "Invalid element path." if path.include?("..") || path.match?(/[<"']/ )

    matches = doc.css(path)
    raise ArgumentError, "Element not found." if matches.empty?
    raise ArgumentError, "Element path is ambiguous (#{matches.size} matches)." if matches.size > 1

    matches.first
  end

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
    title = doc.at("title")&.text.to_s.strip
    return title if title.present?

    rel == "index.html" ? "Home" : rel.delete_suffix(".html").tr("-_/", " ").split.map(&:capitalize).join(" ")
  rescue StandardError
    rel
  end

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

  def rewrite_asset_urls!(doc)
    doc.css("[href], [src], [poster]").each do |node|
      ASSET_ATTRS.each do |attr|
        raw = node[attr].to_s
        next if raw.blank? || raw.start_with?("#", "mailto:", "tel:", "http://", "https://", "//", "data:")

        clean = raw.sub(%r{\A\./}, "").sub(%r{\A/+}, "")
        next if clean.blank? || clean.include?("..")

        file_part, query = clean.split("?", 2)
        next if file_part.blank?

        if attr == "href" && html_page_href?(file_part)
          page_path = normalize_editor_page_path(file_part)
          node["data-xbolt-page"] = page_path
          node[attr] = "#xbolt-page:#{page_path}"
          next
        end

        proxied = asset_proxy_path(file_part)
        node[attr] = query.present? ? "#{proxied}?#{query}" : proxied
      end
    end

    doc.css("style").each do |style_node|
      next if style_node["data-xbolt-static-editor"].present?

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

  def demangle_editor_href(value)
    raw = value.to_s.strip
    if raw.start_with?("#xbolt-page:")
      page = raw.delete_prefix("#xbolt-page:")
      return "index.html" if page.blank? || page == "/"

      slug = page.sub(%r{\A/+}, "").sub(%r{\.html?\z}i, "")
      return "index.html" if slug.blank? || slug == "index"

      return "#{slug}.html"
    end
    raw
  end

  def demangle_editor_src(value)
    raw = value.to_s.strip
    prefix = "/dashboard/website/static/assets/"
    return raw.delete_prefix(prefix) if raw.start_with?(prefix)

    raw
  end

  def inject_editor_styles!(doc)
    style = Nokogiri::XML::Node.new("style", doc)
    style["data-xbolt-static-editor"] = "true"
    style.content = <<~CSS
      [data-xbolt-hover]{
        outline:2px solid rgba(245,158,11,.7) !important;
        outline-offset:2px !important;
      }
      [data-xbolt-selected]{
        outline:2px solid #f59e0b !important;
        outline-offset:3px !important;
        box-shadow:0 0 0 4px rgba(245,158,11,.18) !important;
      }
      [data-xbolt-editable-hint]{ cursor:text; }
    CSS
    (doc.at("head") || doc.root).add_child(style)
  end

  def inject_editor_runtime!(doc)
    script = Nokogiri::XML::Node.new("script", doc)
    script["data-xbolt-static-editor-runtime"] = "true"
    script.content = <<~JS
      (function () {
        if (window.__xboltEditorRuntime) return;
        window.__xboltEditorRuntime = true;

        function isEditorChrome(el) {
          return !!(el && el.closest && el.closest("#{EDITOR_SKIP}"));
        }

        function cssEscape(value) {
          if (window.CSS && CSS.escape) return CSS.escape(value);
          return String(value).replace(/[^a-zA-Z0-9_-]/g, "\\\\$&");
        }

        function stableClass(node) {
          if (!node.classList || !node.classList.length) return "";
          for (var i = 0; i < node.classList.length; i++) {
            var c = node.classList[i];
            if (!/^[a-zA-Z][\\w-]*$/.test(c)) continue;
            if (c.indexOf("xbolt") !== -1) continue;
            return "." + cssEscape(c);
          }
          return "";
        }

        function buildPath(el) {
          if (!el || el.nodeType !== 1) return null;
          if (el.id && document.querySelectorAll("#" + cssEscape(el.id)).length === 1) {
            return "#" + cssEscape(el.id);
          }
          var parts = [];
          var node = el;
          while (node && node.nodeType === 1 && node !== document.documentElement) {
            if (node.id && document.querySelectorAll("#" + cssEscape(node.id)).length === 1) {
              parts.unshift("#" + cssEscape(node.id));
              break;
            }
            var tag = node.tagName.toLowerCase();
            var parent = node.parentElement;
            if (!parent) {
              parts.unshift(tag + stableClass(node));
              break;
            }
            var siblings = Array.prototype.filter.call(parent.children, function (child) {
              return child.tagName === node.tagName;
            });
            var index = siblings.indexOf(node) + 1;
            // Always include nth-of-type so Nokogiri css() never matches sibling groups.
            parts.unshift(tag + stableClass(node) + ":nth-of-type(" + index + ")");
            node = parent;
            if (parts[0] && parts[0].charAt(0) === "#") break;
          }
          return parts.join(" > ");
        }

        function nearestBlock(el) {
          if (!el || !el.closest) return el;
          return el.closest("article, section, li, .review-card, .card, .faq-item, .service-card, header, footer, nav, main > div") || el;
        }

        function post(type, detail) {
          try {
            window.parent.postMessage(Object.assign({ source: "xbolt-editor" }, detail, { type: type }), "*");
          } catch (e) {}
        }

        var selected = null;

        function clearHover() {
          document.querySelectorAll("[data-xbolt-hover]").forEach(function (n) {
            n.removeAttribute("data-xbolt-hover");
          });
        }

        function select(el) {
          if (!el || isEditorChrome(el)) return;
          document.querySelectorAll("[data-xbolt-selected]").forEach(function (n) {
            n.removeAttribute("data-xbolt-selected");
          });
          selected = el;
          el.setAttribute("data-xbolt-selected", "true");
          var path = buildPath(el);
          var block = nearestBlock(el);
          var rect = el.getBoundingClientRect();
          var computed = window.getComputedStyle(el);
          var styles = {};
          #{STYLE_PROPS.map { |p| "styles[#{p.to_json}] = computed.getPropertyValue(#{p.to_json});" }.join("\n          ")}
          post("select", {
            path: path,
            blockPath: buildPath(block),
            tag: el.tagName.toLowerCase(),
            text: (el.innerText || "").trim().slice(0, 5000),
            html: el.outerHTML.slice(0, 50000),
            attrs: {
              href: el.getAttribute("href") || "",
              src: el.getAttribute("src") || "",
              alt: el.getAttribute("alt") || "",
              class: el.getAttribute("class") || "",
              id: el.getAttribute("id") || "",
              title: el.getAttribute("title") || ""
            },
            styles: styles,
            rect: { top: rect.top, left: rect.left, width: rect.width, height: rect.height },
            isImage: el.tagName.toLowerCase() === "img" || !!(styles["background-image"] && styles["background-image"] !== "none")
          });
        }

        document.addEventListener("mouseover", function (event) {
          var el = event.target;
          if (!el || el === document.documentElement || el === document.body || isEditorChrome(el)) return;
          clearHover();
          el.setAttribute("data-xbolt-hover", "true");
        }, true);

        document.addEventListener("mouseout", function () {
          clearHover();
        }, true);

        document.addEventListener("click", function (event) {
          var el = event.target.closest("*");
          if (!el || isEditorChrome(el)) return;
          event.preventDefault();
          event.stopPropagation();
          select(el);
        }, true);

        document.addEventListener("contextmenu", function (event) {
          var el = event.target.closest("*");
          if (!el || isEditorChrome(el)) return;
          event.preventDefault();
          event.stopPropagation();
          select(el);
          var path = buildPath(el);
          var bg = (window.getComputedStyle(el).getPropertyValue("background-image") || "");
          var block = nearestBlock(el);
          post("contextmenu", {
            path: path,
            blockPath: buildPath(block),
            tag: el.tagName.toLowerCase(),
            x: event.clientX,
            y: event.clientY,
            isImage: el.tagName.toLowerCase() === "img" || (bg && bg !== "none")
          });
        }, true);

        document.addEventListener("dblclick", function (event) {
          var link = event.target.closest("a[href], a[data-xbolt-page]");
          if (!link) return;
          event.preventDefault();
          event.stopPropagation();
          post("navigate", {
            page: link.getAttribute("data-xbolt-page") || link.getAttribute("href")
          });
        }, true);

        window.addEventListener("message", function (event) {
          var data = event.data;
          if (!data || data.source !== "xbolt-editor-parent") return;
          if (data.type === "clear-selection") {
            document.querySelectorAll("[data-xbolt-selected]").forEach(function (n) {
              n.removeAttribute("data-xbolt-selected");
            });
            selected = null;
          }
          if (data.type === "select-path" && data.path) {
            try {
              var node = document.querySelector(data.path);
              if (node) select(node);
            } catch (e) {}
          }
          if (data.type === "apply-text" && selected) {
            selected.textContent = data.value || "";
          }
          if (data.type === "apply-styles" && selected && data.styles) {
            Object.keys(data.styles).forEach(function (key) {
              selected.style.setProperty(key, data.styles[key] || "");
            });
          }
        });

        // Force review cards visible in editor if present.
        var grid = document.getElementById("reviews-grid");
        if (grid) {
          Array.prototype.forEach.call(grid.querySelectorAll(".review-card"), function (card) {
            card.style.display = "";
          });
          var moreBtn = document.getElementById("load-more-reviews");
          if (moreBtn) moreBtn.style.display = "none";
        }

        post("ready", {});
      })();
    JS
    (doc.at("body") || doc.root).add_child(script)
  end

  def parse_inline_style(raw)
    raw.to_s.split(";").each_with_object({}) do |chunk, hash|
      prop, value = chunk.split(":", 2)
      next if prop.blank? || value.blank?

      hash[prop.strip.downcase] = value.strip
    end
  end

  def annotate_copy_label!(node)
    heading = node.at_css(".review-name, h1, h2, h3, h4, h5, h6, p, span, strong")
    return if heading.nil?

    text = heading.text.to_s.strip
    return if text.blank?

    heading.content = text.end_with?("(copy)") ? text : "#{text} (copy)"
  end

  def store_uploaded_image!(uploaded_file)
    raise ArgumentError, "No file uploaded." if uploaded_file.blank?

    content_type = uploaded_file.content_type.to_s
    raise ArgumentError, "Unsupported image type." unless ALLOWED_IMAGE_TYPES.include?(content_type)

    size = uploaded_file.size.to_i
    raise ArgumentError, "Image is too large." if size <= 0 || size > MAX_IMAGE_BYTES

    ext =
      case content_type
      when "image/jpeg" then ".jpg"
      when "image/png" then ".png"
      when "image/webp" then ".webp"
      when "image/gif" then ".gif"
      when "image/svg+xml" then ".svg"
      else File.extname(uploaded_file.original_filename.to_s).presence || ".bin"
      end

    dir = @site_root.join("assets", "editor")
    FileUtils.mkdir_p(dir)
    name = "#{Time.current.strftime('%Y%m%d%H%M%S')}-#{SecureRandom.hex(6)}#{ext}"
    abs = dir.join(name)
    File.open(abs, "wb") { |f| IO.copy_stream(uploaded_file.tempfile, f) }
    asset_proxy_path("assets/editor/#{name}")
  end

  def versioned_backup!(abs)
    FileUtils.mkdir_p(@backup_root)
    clear_redo_stack!
    stamp = Time.current.strftime("%Y%m%d-%H%M%S-%L")
    rel = Pathname.new(abs).relative_path_from(@site_root).to_s.tr("\\", "/")
    safe = rel.gsub("/", "__")
    dest = @backup_root.join("#{stamp}__#{safe}")
    FileUtils.cp(abs, dest)

    all = Dir.glob(@backup_root.join("*")).select { |f| File.file?(f) }.sort.reverse
    all.drop(BACKUP_KEEP).each { |old| FileUtils.rm_f(old) }
  end

  def editor_backups_for(abs)
    rel = Pathname.new(abs).relative_path_from(@site_root).to_s.tr("\\", "/")
    safe = rel.gsub("/", "__")
    Dir.glob(@backup_root.join("*__#{safe}")).sort.reverse
  end

  def newest_backup(root)
    return nil unless Dir.exist?(root)

    Dir.glob(root.join("*")).select { |f| File.file?(f) }.sort.reverse.first
  end

  def restore_target_from_backup!(backup_path)
    basename = File.basename(backup_path.to_s)
    match = basename.match(/\A\d{8}-\d{6}-\d{3}__(.+)\z/)
    raise ArgumentError, "Corrupt backup." if match.nil?

    rel = match[1].gsub("__", "/")
    raise ArgumentError, "Invalid backup path." if rel.blank? || rel.include?("..")

    abs = @site_root.join(rel).cleanpath
    raise ArgumentError, "Invalid backup target." unless abs.to_s.start_with?(@site_root.to_s)

    abs
  end

  def push_history_copy!(root, abs)
    FileUtils.mkdir_p(root)
    stamp = Time.current.strftime("%Y%m%d-%H%M%S-%L")
    rel = Pathname.new(abs).relative_path_from(@site_root).to_s.tr("\\", "/")
    safe = rel.gsub("/", "__")
    FileUtils.cp(abs, root.join("#{stamp}__#{safe}"))
    all = Dir.glob(root.join("*")).select { |f| File.file?(f) }.sort.reverse
    all.drop(BACKUP_KEEP).each { |old| FileUtils.rm_f(old) }
  end

  def clear_redo_stack!
    return unless Dir.exist?(@redo_root)

    Dir.glob(@redo_root.join("*")).each { |f| FileUtils.rm_f(f) }
  end

  def write_raw!(abs, contents)
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
