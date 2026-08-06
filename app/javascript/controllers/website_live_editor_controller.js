import { Controller } from "@hotwired/stimulus"

/**
 * Live website editor.
 * Soft iframe reloads (not document.write) so CDN/CSS/font requests keep working.
 * Double-click page links soft-navigates inside the editor.
 */
export default class extends Controller {
  static targets = [
    "frame",
    "toolbar",
    "status",
    "statusToast",
    "statusDot",
    "pageSwitcher",
    "pageMenu",
    "pagesBtn",
    "bubble",
    "bubbleLabel",
    "bubbleInput",
    "cardHint",
    "duplicateBtn"
  ]

  static values = {
    previewUrl: String,
    staticPath: String,
    staticUpdateUrl: String,
    siteUrl: String,
    dashboardUrl: String,
    pages: String,
    deployed: Boolean
  }

  connect() {
    this.saveTimer = null
    this.sortables = []
    this.selected = null
    this.selectedEl = null
    this.selectedItem = null
    this.clickHandler = null
    this.dblClickHandler = null
    this.keyHandler = null
    this.pendingRefresh = null
    this.refreshResolver = null
    this.lastClickAt = 0
    this.docClickOutside = this.onDocumentClick.bind(this)
    document.addEventListener("click", this.docClickOutside)
    this.closeInspector()
  }

  disconnect() {
    window.clearTimeout(this.saveTimer)
    this.destroySortables()
    this.teardownFrameListeners()
    document.removeEventListener("click", this.docClickOutside)
    if (this.refreshResolver) this.refreshResolver()
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  frameDoc() {
    return this.hasFrameTarget ? this.frameTarget.contentDocument : null
  }

  frameWin() {
    return this.hasFrameTarget ? this.frameTarget.contentWindow : null
  }

  pagesList() {
    try {
      return JSON.parse(this.pagesValue || "[]")
    } catch {
      return []
    }
  }

  previewUrlFor(path = this.staticPathValue || "/") {
    const current = this.previewUrlValue || this.frameTarget?.getAttribute("src") || ""
    const base = current.split("?")[0] || "/dashboard/website/static/preview"
    return `${base}?path=${encodeURIComponent(path || "/")}`
  }

  onFrameLoad() {
    const doc = this.frameDoc()
    if (!doc?.body) return

    const pending = this.pendingRefresh
    this.pendingRefresh = null

    this.destroySortables()
    this.teardownFrameListeners()
    this.bindEditing(doc)
    this.bindSortables(doc)

    if (pending?.scrollX != null || pending?.scrollY != null) {
      doc.defaultView?.scrollTo(pending.scrollX || 0, pending.scrollY || 0)
    }

    if (pending?.selectCardIndex != null && pending?.containerIndex != null) {
      const container = doc.querySelector(
        `[data-xbolt-items][data-xbolt-container-index="${pending.containerIndex}"]`
      )
      const card = container?.querySelector(
        `[data-xbolt-item][data-xbolt-item-index="${pending.selectCardIndex}"]`
      )
      if (card) this.selectCard(card)
      else this.clearSelection({ keepStatus: true })
    } else if (!pending?.keepSelection) {
      this.clearSelection({ keepStatus: true })
    }

    this.setStatus(pending?.status || "Ready", pending?.tone || "")
    if (this.refreshResolver) {
      const resolve = this.refreshResolver
      this.refreshResolver = null
      resolve()
    }
  }

  onDocumentClick(event) {
    if (!this.hasPageMenuTarget || this.pageMenuTarget.hasAttribute("hidden")) return
    if (event.target.closest?.(".xb-page-menu")) return
    if (event.target.closest?.("[data-action*='togglePages']")) return
    this.hidePageMenu()
  }

  togglePages(event) {
    event?.preventDefault()
    event?.stopPropagation()
    if (!this.hasPageMenuTarget) return
    if (this.pageMenuTarget.hasAttribute("hidden")) {
      const anchor = this.pagesBtnTarget || event.currentTarget
      const rect = anchor?.getBoundingClientRect?.()
      if (rect) {
        this.pageMenuTarget.style.top = `${Math.max(12, rect.top)}px`
        this.pageMenuTarget.style.left = `${rect.right + 10}px`
      }
      this.pageMenuTarget.removeAttribute("hidden")
      this.pagesBtnTarget?.classList.add("is-active")
    } else {
      this.hidePageMenu()
    }
  }

  hidePageMenu() {
    this.pageMenuTarget?.setAttribute("hidden", "")
    this.pagesBtnTarget?.classList.remove("is-active")
  }

  switchPage(event) {
    const url = event.target.value
    if (!url) return
    const page = this.pagesList().find((entry) => entry.url === url)
    if (page) this.openEditorPage(page)
    else window.location.assign(url)
  }

  reloadPreview() {
    return this.refreshLive({ reason: "refresh", status: "Ready" })
  }

  bindEditing(doc) {
    this.clickHandler = (event) => {
      if (event.target.closest?.("#xbolt-live-editor-ignore")) return

      // Let the second click of a double-click pass through to dblclick.
      const now = Date.now()
      const isDouble = now - this.lastClickAt < 320
      this.lastClickAt = now

      const link = event.target.closest?.("a[href], a[data-xbolt-page]")
      if (link && isDouble) {
        event.preventDefault()
        event.stopPropagation()
        this.handlePageNavigation(link)
        return
      }

      const editable = event.target.closest?.("[data-xbolt-editable]")
      const item = event.target.closest?.("[data-xbolt-item]")

      if (editable) {
        event.preventDefault()
        event.stopPropagation()
        this.openEditor(editable, item)
        return
      }

      if (item) {
        event.preventDefault()
        event.stopPropagation()
        this.selectCard(item)
        return
      }

      if (link || event.target.closest?.("button")) {
        event.preventDefault()
        event.stopPropagation()
      }
    }

    this.dblClickHandler = (event) => {
      const link = event.target.closest?.("a[href], a[data-xbolt-page]")
      if (!link) return
      event.preventDefault()
      event.stopPropagation()
      this.handlePageNavigation(link)
    }

    this.keyHandler = (event) => {
      if (event.key === "Escape") {
        this.doneEditing()
        this.hidePageMenu()
      }
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "s") {
        event.preventDefault()
        this.saveNow()
      }
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "d" && this.cardTarget()) {
        event.preventDefault()
        this.duplicateCard()
      }
    }

    doc.addEventListener("click", this.clickHandler, true)
    doc.addEventListener("dblclick", this.dblClickHandler, true)
    doc.addEventListener("keydown", this.keyHandler, true)
  }

  teardownFrameListeners() {
    const doc = this.frameDoc()
    if (!doc) return
    if (this.clickHandler) doc.removeEventListener("click", this.clickHandler, true)
    if (this.dblClickHandler) doc.removeEventListener("dblclick", this.dblClickHandler, true)
    if (this.keyHandler) doc.removeEventListener("keydown", this.keyHandler, true)
    this.clickHandler = null
    this.dblClickHandler = null
    this.keyHandler = null
  }

  handlePageNavigation(link) {
    const page =
      this.resolveEditorPage(link.getAttribute("data-xbolt-page")) ||
      this.resolveEditorPage(link.getAttribute("href"))

    if (!page) {
      this.setStatus("No matching page", "error")
      return
    }

    this.openEditorPage(page)
  }

  openEditorPage(page) {
    if (!page?.path) return
    this.hidePageMenu()
    this.staticPathValue = page.path
    this.previewUrlValue = this.previewUrlFor(page.path)

    try {
      window.history.replaceState({}, "", page.url)
    } catch {
      // ignore
    }

    if (this.hasPageSwitcherTarget) {
      this.pageSwitcherTarget.value = page.url
    }

    document.querySelectorAll(".xb-page-link").forEach((node) => {
      node.classList.toggle("is-current", node.getAttribute("href") === page.url)
    })

    this.setStatus(`Opening ${page.title || page.path}…`, "saving")
    this.refreshLive({ reason: "navigate", status: `Editing ${page.title || page.path}`, tone: "ok" })
  }

  resolveEditorPage(href) {
    if (!href) return null
    let raw = href.trim()
    if (!raw || raw.startsWith("mailto:") || raw.startsWith("tel:") || raw.startsWith("javascript:")) {
      return null
    }

    if (raw.startsWith("#xbolt-page:")) {
      raw = raw.slice("#xbolt-page:".length)
    } else if (raw.startsWith("#")) {
      return null
    }

    // data-xbolt-page values are already normalized paths.
    if (raw.startsWith("/") && !raw.includes("://") && !raw.includes(".html")) {
      return this.pagesList().find((page) => page.path === raw) || null
    }

    let path = raw
    try {
      if (/^https?:\/\//i.test(raw) || raw.startsWith("//")) {
        const url = new URL(raw, window.location.origin)
        const siteHost = (() => {
          try {
            return new URL(this.siteUrlValue).host
          } catch {
            return ""
          }
        })()
        if (url.origin !== window.location.origin && url.host !== siteHost) return null
        path = url.pathname + url.search
      }
    } catch {
      return null
    }

    // Unwrap asset-proxy or preview URLs back to a site path.
    const assetMatch = path.match(/\/dashboard\/website\/static\/assets\/(.+)$/i)
    if (assetMatch) path = assetMatch[1]

    const previewMatch = path.match(/[?&]path=([^&]+)/i)
    if (path.includes("/dashboard/website/static/preview") && previewMatch) {
      path = decodeURIComponent(previewMatch[1])
    }

    path = path.split("?")[0].split("#")[0]
    path = path.replace(/^\.\//, "")
    if (!path.startsWith("/")) path = `/${path}`
    if (path.endsWith("/index.html") || path.endsWith("/index.htm")) {
      path = path.replace(/\/index\.html?$/i, "") || "/"
    }
    if (/\.html?$/i.test(path)) path = path.replace(/\.html?$/i, "") || "/"
    if (path !== "/" && path.endsWith("/")) path = path.slice(0, -1)
    if (path === "/index") path = "/"

    return this.pagesList().find((page) => page.path === path) || null
  }

  bindSortables(doc) {
    if (!window.Sortable) return

    doc.querySelectorAll("[data-xbolt-items]").forEach((container) => {
      this.sortables.push(
        window.Sortable.create(container, {
          draggable: "[data-xbolt-item]",
          ghostClass: "xbolt-drag-ghost",
          animation: 160,
          handle: "[data-xbolt-item]",
          filter: "[data-xbolt-editable]",
          preventOnFilter: false,
          delay: 120,
          delayOnTouchOnly: true,
          onEnd: (event) => {
            if (event.oldIndex === event.newIndex) return
            if (String(container.dataset.xboltContainerIndex) === "dynamic-reviews") {
              this.setStatus("Review reorder not supported", "error")
              this.refreshLive({ reason: "reorder-rollback" })
              return
            }
            this.saveReorder({
              containerIndex: Number(container.dataset.xboltContainerIndex || 0),
              oldIndex: event.oldIndex,
              newIndex: event.newIndex
            })
          }
        })
      )
    })
  }

  destroySortables() {
    this.sortables.forEach((sortable) => sortable.destroy())
    this.sortables = []
  }

  openInspector() {
    this.bubbleTarget?.classList.add("is-open")
  }

  closeInspector() {
    this.bubbleTarget?.classList.remove("is-open")
  }

  openEditor(element, item = null) {
    const raw = element.dataset.xboltTextIndex
    if (raw == null || raw === "") return

    this.clearHighlights()
    this.selectedEl = element
    this.selectedItem = item || element.closest?.("[data-xbolt-item]") || null
    element.setAttribute("data-xbolt-selected", "true")
    this.selectedItem?.setAttribute("data-xbolt-item-selected", "true")

    this.selected = {
      kind: "text",
      textIndex: /^\d+$/.test(String(raw)) ? Number(raw) : raw
    }

    if (this.hasBubbleLabelTarget) {
      this.bubbleLabelTarget.textContent = this.labelFor(this.selected.textIndex)
    }
    if (this.hasBubbleInputTarget) {
      this.bubbleInputTarget.value = element.textContent || ""
      this.bubbleInputTarget.disabled = false
    }
    this.toggleCardHint(Boolean(this.selectedItem))
    this.openInspector()
    this.bubbleInputTarget?.focus()
    this.bubbleInputTarget?.select()
    this.setStatus("Editing")
  }

  selectCard(item) {
    this.clearHighlights()
    this.selectedEl = item
    this.selectedItem = item
    item.setAttribute("data-xbolt-item-selected", "true")
    this.selected = {
      kind: "card",
      containerIndex: item.closest("[data-xbolt-items]")?.dataset?.xboltContainerIndex,
      itemIndex: item.dataset.xboltItemIndex
    }

    if (this.hasBubbleLabelTarget) {
      this.bubbleLabelTarget.textContent = `Card ${(Number(item.dataset.xboltItemIndex) || 0) + 1}`
    }
    if (this.hasBubbleInputTarget) {
      this.bubbleInputTarget.value = (item.textContent || "").replace(/\s+/g, " ").trim().slice(0, 280)
      this.bubbleInputTarget.disabled = true
    }
    this.toggleCardHint(true)
    this.openInspector()
    this.setStatus("Card selected")
  }

  toggleCardHint(show) {
    if (!this.hasCardHintTarget) return
    if (show) this.cardHintTarget.removeAttribute("hidden")
    else this.cardHintTarget.setAttribute("hidden", "")
  }

  clearHighlights() {
    const doc = this.frameDoc()
    doc?.querySelectorAll("[data-xbolt-selected], [data-xbolt-item-selected]").forEach((node) => {
      node.removeAttribute("data-xbolt-selected")
      node.removeAttribute("data-xbolt-item-selected")
    })
  }

  clearSelection({ keepStatus = false } = {}) {
    this.clearHighlights()
    this.selectedEl = null
    this.selectedItem = null
    this.selected = null
    this.closeInspector()
    if (!keepStatus) this.setStatus("Ready")
  }

  onBubbleInput() {
    if (!this.selectedEl || this.selected?.kind !== "text") return
    this.selectedEl.textContent = this.bubbleInputTarget.value
    this.scheduleSave()
  }

  doneEditing() {
    const hadTextEdit = this.selected?.kind === "text"
    this.flushSave().finally(() => {
      this.clearSelection()
      this.setStatus(hadTextEdit ? "Saved" : "Ready", hadTextEdit ? "ok" : "")
    })
  }

  saveNow() {
    this.flushSave({ keepOpen: true })
  }

  scheduleSave() {
    this.setStatus("Saving…", "saving")
    window.clearTimeout(this.saveTimer)
    this.saveTimer = window.setTimeout(() => this.flushSave({ keepOpen: true }), 450)
  }

  flushSave({ keepOpen = false } = {}) {
    window.clearTimeout(this.saveTimer)
    if (!this.selected || this.selected.kind !== "text") return Promise.resolve()

    const value = this.bubbleInputTarget?.value ?? this.selectedEl?.textContent ?? ""
    this.setStatus("Saving…", "saving")

    return this.patch({
      path: this.staticPathValue,
      text_index: this.selected.textIndex,
      value
    })
      .then(() => {
        this.setStatus("Saved", "ok")
        if (!keepOpen) this.clearSelection({ keepStatus: true })
      })
      .catch((error) => this.setStatus(error.message || "Save failed", "error"))
  }

  saveReorder({ containerIndex, oldIndex, newIndex }) {
    this.setStatus("Saving…", "saving")
    return this.patch({
      path: this.staticPathValue,
      reorder: {
        container_index: containerIndex,
        old_index: oldIndex,
        new_index: newIndex
      }
    })
      .then(() => this.setStatus("Saved", "ok"))
      .catch((error) => {
        this.setStatus(error.message || "Save failed", "error")
        this.refreshLive({ reason: "reorder-error" })
      })
  }

  cardTarget() {
    return this.selectedItem || this.selectedEl?.closest?.("[data-xbolt-item]") || null
  }

  cardCoords(item = this.cardTarget()) {
    if (!item) return null
    const container = item.closest("[data-xbolt-items]")
    if (!container) return null
    return {
      containerIndex: container.dataset.xboltContainerIndex,
      itemIndex: item.dataset.xboltItemIndex,
      container,
      item
    }
  }

  async duplicateCard() {
    const coords = this.cardCoords()
    if (!coords) {
      this.setStatus("Select a card first", "error")
      return
    }

    const { item, container } = coords
    const isDynamic = String(coords.containerIndex) === "dynamic-reviews"
    const clone = item.cloneNode(true)
    clone.removeAttribute("data-xbolt-item-selected")
    clone.querySelectorAll("[data-xbolt-selected]").forEach((node) => node.removeAttribute("data-xbolt-selected"))
    // Cloned static text must not keep the source indexes (would overwrite originals).
    if (!isDynamic) this.detachEditableIndexes(clone)
    this.annotateCopyLabel(clone)
    item.after(clone)
    this.reindexItems(container)
    if (isDynamic) this.reindexDynamicReviews(container)
    this.destroySortables()
    this.bindSortables(this.frameDoc())
    this.selectCard(clone)

    this.setStatus("Duplicating…", "saving")
    try {
      await this.patch({
        path: this.staticPathValue,
        duplicate: {
          container_index: coords.containerIndex,
          item_index: coords.itemIndex
        }
      })
      // Keep the optimistic card — never remount/refresh (JS-rendered pages lose cards past the first batch).
      this.setStatus("Card duplicated", "ok")
    } catch (error) {
      clone.remove()
      this.reindexItems(container)
      if (isDynamic) this.reindexDynamicReviews(container)
      this.destroySortables()
      this.bindSortables(this.frameDoc())
      this.setStatus(error.message || "Duplicate failed", "error")
    }
  }

  async deleteCard() {
    const coords = this.cardCoords()
    if (!coords) {
      this.setStatus("Select a card first", "error")
      return
    }
    if (!window.confirm("Delete this card from the live site?")) return

    const { item, container } = coords
    const isDynamic = String(coords.containerIndex) === "dynamic-reviews"
    const placeholder = document.createComment("xbolt-deleted-card")
    item.after(placeholder)
    item.remove()
    this.reindexItems(container)
    if (isDynamic) this.reindexDynamicReviews(container)
    this.clearSelection({ keepStatus: true })
    this.destroySortables()
    this.bindSortables(this.frameDoc())

    this.setStatus("Deleting…", "saving")
    try {
      await this.patch({
        path: this.staticPathValue,
        delete_item: {
          container_index: coords.containerIndex,
          item_index: coords.itemIndex
        }
      })
      this.setStatus("Card deleted", "ok")
    } catch (error) {
      placeholder.replaceWith(item)
      this.reindexItems(container)
      if (isDynamic) this.reindexDynamicReviews(container)
      this.destroySortables()
      this.bindSortables(this.frameDoc())
      this.setStatus(error.message || "Delete failed", "error")
    }
  }

  reindexItems(container) {
    if (!container) return
    Array.from(container.children)
      .filter((child) => child.hasAttribute?.("data-xbolt-item"))
      .forEach((child, index) => {
        child.setAttribute("data-xbolt-item-index", String(index))
      })
  }

  reindexDynamicReviews(container) {
    if (!container) return
    Array.from(container.children)
      .filter((child) => child.hasAttribute?.("data-xbolt-item"))
      .forEach((card, index) => {
        card.setAttribute("data-xbolt-item-index", String(index))
        // Prefer name text (letter-spacing), not the avatar initial circle.
        const name =
          card.querySelector("div[style*='letter-spacing:0.5px']") ||
          card.querySelector("div[style*='letter-spacing: 0.5px']")
        const service = card.querySelector("div[style*='text-transform:uppercase']")
        const body = card.querySelector("p.review-text, p")
        ;[
          [name, "name"],
          [service, "service"],
          [body, "reviewText"]
        ].forEach(([node, field]) => {
          if (!node) return
          node.setAttribute("data-xbolt-editable", "true")
          node.setAttribute("data-xbolt-text-index", `review:${index}:${field}`)
        })
      })
  }

  annotateCopyLabel(root) {
    const heading =
      root.querySelector?.(".review-name") ||
      root.querySelector?.("div[style*='letter-spacing:0.5px']") ||
      root.querySelector?.("div[style*='letter-spacing: 0.5px']") ||
      root.querySelector?.("h1,h2,h3,h4,h5,h6") ||
      root.querySelector?.("p,span,strong")
    if (!heading) return
    const text = (heading.textContent || "").trim()
    if (!text || text.endsWith("(copy)")) return
    heading.textContent = `${text} (copy)`
    const avatar = root.querySelector?.(".review-avatar")
    if (avatar) avatar.textContent = (heading.textContent || "").trim().charAt(0).toUpperCase()
  }

  detachEditableIndexes(root) {
    root.querySelectorAll?.("[data-xbolt-editable]").forEach((el) => {
      el.removeAttribute("data-xbolt-text-index")
      el.removeAttribute("data-xbolt-editable")
      el.removeAttribute("data-xbolt-selected")
    })
  }

  /**
   * Soft-reload the preview iframe via src navigation.
   * This preserves CSP + allows external CDN/font/script requests.
   * Never use document.write — that blanks the page and blocks remote assets.
   */
  refreshLive({
    reason = "",
    selectCardIndex = null,
    containerIndex = null,
    status = "Ready",
    tone = ""
  } = {}) {
    if (!this.hasFrameTarget) return Promise.resolve()

    const win = this.frameWin()
    const scrollX = win?.scrollX || 0
    const scrollY = win?.scrollY || 0
    const url = `${this.previewUrlFor(this.staticPathValue)}&t=${Date.now()}`

    this.pendingRefresh = {
      reason,
      selectCardIndex,
      containerIndex,
      scrollX,
      scrollY,
      status,
      tone
    }

    this.setStatus(reason === "refresh" ? "Refreshing…" : "Updating…", "saving")

    return new Promise((resolve) => {
      this.refreshResolver = resolve
      this.frameTarget.src = url

      // Safety timeout so callers don't hang if load never fires.
      window.setTimeout(() => {
        if (this.refreshResolver === resolve) {
          this.refreshResolver = null
          resolve()
        }
      }, 12000)
    })
  }

  async copyHtml() {
    const node = this.cardTarget() || this.selectedEl
    if (!node) {
      this.setStatus("Select something first", "error")
      return
    }

    const clone = node.cloneNode(true)
    clone.querySelectorAll("*").forEach((el) => this.stripEditorAttrs(el))
    this.stripEditorAttrs(clone)

    try {
      await navigator.clipboard.writeText(clone.outerHTML)
      this.setStatus("HTML copied", "ok")
    } catch {
      this.setStatus("Could not copy HTML", "error")
    }
  }

  async copyCss() {
    const node = this.cardTarget() || this.selectedEl
    const win = this.frameWin()
    if (!node || !win) {
      this.setStatus("Select something first", "error")
      return
    }

    const computed = win.getComputedStyle(node)
    const props = [
      "display", "position", "width", "max-width", "height", "margin", "padding",
      "background", "background-color", "color", "border", "border-radius",
      "box-shadow", "font-family", "font-size", "font-weight", "line-height",
      "letter-spacing", "text-align", "gap", "grid-template-columns", "flex-direction"
    ]

    const className = (node.className && typeof node.className === "string" && node.className.trim())
      ? `.${node.className.trim().split(/\s+/).slice(0, 3).join(".")}`
      : node.tagName.toLowerCase()

    const body = props
      .map((prop) => {
        const value = computed.getPropertyValue(prop)
        return value && value !== "none" && value !== "normal" && value !== "auto" && value !== "0px"
          ? `  ${prop}: ${value};`
          : null
      })
      .filter(Boolean)
      .join("\n")

    try {
      await navigator.clipboard.writeText(`${className} {\n${body}\n}`)
      this.setStatus("CSS copied", "ok")
    } catch {
      this.setStatus("Could not copy CSS", "error")
    }
  }

  stripEditorAttrs(el) {
    ;[
      "data-xbolt-editable",
      "data-xbolt-text-index",
      "data-xbolt-selected",
      "data-xbolt-item",
      "data-xbolt-item-index",
      "data-xbolt-item-selected",
      "data-xbolt-items",
      "data-xbolt-container-index",
      "data-xbolt-page",
      "draggable"
    ].forEach((attr) => el.removeAttribute?.(attr))
  }

  patch(body) {
    return fetch(this.staticUpdateUrlValue, {
      method: "PATCH",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      body: JSON.stringify(body)
    }).then((response) =>
      response.json().then((payload) => {
        if (!response.ok) throw new Error(payload.message || "Save failed")
        return payload
      })
    )
  }

  setStatus(message, tone = "") {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.title = message
    }
    if (this.hasStatusToastTarget) {
      this.statusToastTarget.classList.remove("is-ok", "is-saving", "is-error")
      if (tone === "error" || tone === "saving" || tone === "ok") {
        this.statusToastTarget.classList.add(`is-${tone}`)
      }
      this.statusToastTarget.title = message
    }
  }

  labelFor(textIndex) {
    if (typeof textIndex === "string" && textIndex.startsWith("review:")) {
      const parts = textIndex.split(":")
      return `Review ${Number(parts[1]) + 1} · ${parts[2] || "text"}`
    }
    return `Text ${Number(textIndex) + 1}`
  }
}
