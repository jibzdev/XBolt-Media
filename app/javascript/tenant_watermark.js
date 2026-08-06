/*
 * XBolt watermark badge for deployed tenant sites.
 *
 * Loaded as a classic script (never an ES module) because tenant sites are
 * arbitrary static builds. Installed onto a tenant by TenantWatermarkInstaller,
 * which copies this file to the site root and adds the <script> tag.
 *
 * Markup is rendered inside a shadow root so the tenant's own CSS cannot
 * restyle or hide the badge.
 */
(function () {
  "use strict";

  var MOUNT_ID = "xbolt-watermark-root";
  var DEFAULTS = {
    href: "https://xboltmedia.com",
    label: "Powered by XBolt Media",
    position: "bottom-right"
  };

  // Must be read synchronously: document.currentScript is null inside callbacks.
  var tag = document.currentScript;

  function option(name, fallback) {
    if (!tag) return fallback;
    var value = tag.getAttribute("data-" + name);
    return value && value.trim() ? value.trim() : fallback;
  }

  var config = {
    href: option("href", DEFAULTS.href),
    label: option("label", DEFAULTS.label),
    position: option("position", DEFAULTS.position)
  };

  function positionStyles(position) {
    switch (position) {
      case "bottom-left":
        return "bottom:16px;left:16px;";
      case "top-right":
        return "top:16px;right:16px;";
      case "top-left":
        return "top:16px;left:16px;";
      default:
        return "bottom:16px;right:16px;";
    }
  }

  // Left-anchored badges must grow rightwards, so the label sits after the icon.
  var opensLeftward = config.position === "bottom-right" || config.position === "top-right";

  function styles() {
    return [
      ":host { all: initial; }",
      ".xb-badge {",
      "  display: flex; align-items: center; gap: 0;",
      "  box-sizing: border-box; height: 34px; padding: 0;",
      "  border-radius: 999px; text-decoration: none;",
      "  background: rgba(9, 9, 11, 0.92); border: 1px solid rgba(245, 158, 11, 0.28);",
      "  box-shadow: 0 6px 20px -6px rgba(0, 0, 0, 0.55);",
      "  font-family: Inter, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;",
      "  cursor: pointer; overflow: hidden;",
      "  transition: border-color 0.25s ease, background 0.25s ease, box-shadow 0.25s ease;",
      opensLeftward ? "  flex-direction: row-reverse;" : "",
      "}",
      ".xb-badge:hover, .xb-badge:focus-visible {",
      "  background: rgba(9, 9, 11, 0.97); border-color: rgba(245, 158, 11, 0.55);",
      "  box-shadow: 0 10px 28px -8px rgba(0, 0, 0, 0.65);",
      "}",
      ".xb-badge:focus-visible { outline: 2px solid rgba(245, 158, 11, 0.6); outline-offset: 2px; }",
      ".xb-icon {",
      "  display: flex; align-items: center; justify-content: center;",
      "  width: 32px; height: 32px; flex: 0 0 32px; color: #fbbf24;",
      "}",
      ".xb-icon svg { width: 15px; height: 15px; display: block; }",
      ".xb-label {",
      "  display: block; white-space: nowrap; color: #fafafa;",
      "  font-size: 12px; font-weight: 600; letter-spacing: -0.01em; line-height: 1;",
      "  max-width: 0; opacity: 0;",
      "  transition: max-width 0.32s cubic-bezier(0.22, 1, 0.36, 1), opacity 0.22s ease, padding 0.32s cubic-bezier(0.22, 1, 0.36, 1);",
      opensLeftward ? "  padding: 0 0 0 0;" : "  padding: 0;",
      "}",
      ".xb-badge:hover .xb-label, .xb-badge:focus-visible .xb-label {",
      "  max-width: 220px; opacity: 1;",
      opensLeftward ? "  padding: 0 4px 0 12px;" : "  padding: 0 12px 0 4px;",
      "}",
      "@media (prefers-reduced-motion: reduce) {",
      "  .xb-badge, .xb-label { transition: none; }",
      "}"
    ].join("\n");
  }

  function build() {
    var link = document.createElement("a");
    link.className = "xb-badge";
    link.href = config.href;
    link.target = "_blank";
    link.rel = "noopener noreferrer";
    link.setAttribute("aria-label", config.label);
    link.setAttribute("title", config.label);

    var icon = document.createElement("span");
    icon.className = "xb-icon";
    icon.setAttribute("aria-hidden", "true");
    icon.innerHTML =
      '<svg viewBox="0 0 20 20" fill="currentColor" focusable="false">' +
      '<path d="M11.983 1.907a.75.75 0 0 0-1.292-.657l-8.5 9.5A.75.75 0 0 0 2.75 12h6.572' +
      'l-1.305 6.093a.75.75 0 0 0 1.292.657l8.5-9.5A.75.75 0 0 0 17.25 8h-6.572l1.305-6.093Z" />' +
      "</svg>";

    var label = document.createElement("span");
    label.className = "xb-label";
    label.textContent = config.label;

    link.appendChild(icon);
    link.appendChild(label);
    return link;
  }

  function mount() {
    if (!document.body || document.getElementById(MOUNT_ID)) return;

    var host = document.createElement("div");
    host.id = MOUNT_ID;
    host.style.cssText =
      "position:fixed;z-index:2147483000;width:auto;height:auto;margin:0;padding:0;" +
      positionStyles(config.position);

    if (host.attachShadow) {
      var shadow = host.attachShadow({ mode: "open" });
      var style = document.createElement("style");
      style.textContent = styles();
      shadow.appendChild(style);
      shadow.appendChild(build());
    } else {
      host.appendChild(build());
    }

    document.body.appendChild(host);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", mount);
  } else {
    mount();
  }
})();
