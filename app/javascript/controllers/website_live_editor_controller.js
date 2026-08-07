import { Controller } from "@hotwired/stimulus"

/**
 * Hybrid website editor: visual path-based editing + Monaco HTML/CSS + right-click menu.
 */
export default class extends Controller {
  static targets = [
    "frame",
    "toolbar",
    "status",
    "statusToast",
    "statusDot",
    "pageMenu",
    "pagesBtn",
    "bubble",
    "bubbleLabel",
    "bubbleInput",
    "undoBtn",
    "redoBtn",
    "codeBtn",
    "codeDrawer",
    "monacoHost",
    "codeBody",
    "codeFallback",
    "cssSources",
    "contextMenu",
    "imagePanel",
    "imagePreview",
    "imageUrl",
    "imageAlt",
    "linkAttr"
  ]

  static values = {
    previewUrl: String,
    staticPath: String,
    staticUpdateUrl: String,
    staticSourceUrl: String,
    staticUndoUrl: String,
    staticRedoUrl: String,
    staticUploadUrl: String,
    siteUrl: String,
    dashboardUrl: String,
    pages: String,
    deployed: Boolean
  }

  connect() {
    this.selected = null
    this.saveTimer = null
    this.styleTimer = null
    this.pendingRefresh = null
    this.refreshResolver = null
    this.monaco = null
    this.monacoEditor = null
    this.monacoReady = false
    this.useCodeFallback = false
    this.codeTab = "html"
    this.sourcePayload = null
    this.activeCssSourceId = null
    this.codeDirty = false
    this.canUndo = false
    this.canRedo = false
    this.busy = false
    this.messageHandler = this.onWindowMessage.bind(this)
    this.docClickOutside = this.onDocumentClick.bind(this)
    this.ctxHandler = this.onContextAction.bind(this)
    this.keyHandler = this.onKeyDown.bind(this)

    window.addEventListener("message", this.messageHandler)
    document.addEventListener("click", this.docClickOutside)
    document.addEventListener("keydown", this.keyHandler)
    this.hasContextMenuTarget && this.contextMenuTarget.addEventListener("click", this.ctxHandler)
    this.closeInspector()
    this.hideContextMenu()
    if (this.deployedValue) this.loadSource()
  }

  async askConfirm(message, options = {}) {
    if (typeof window.showConfirmModal === "function") {
      return window.showConfirmModal(message, options)
    }
    return window.confirm(message)
  }

  disconnect() {
    window.clearTimeout(this.saveTimer)
    window.clearTimeout(this.styleTimer)
    window.removeEventListener("message", this.messageHandler)
    document.removeEventListener("click", this.docClickOutside)
    document.removeEventListener("keydown", this.keyHandler)
    if (this.hasContextMenuTarget) this.contextMenuTarget.removeEventListener("click", this.ctxHandler)
    if (this.refreshResolver) this.refreshResolver()
  }

  onKeyDown(event) {
    const meta = event.metaKey || event.ctrlKey
    if (!meta) return
    const tag = (event.target?.tagName || "").toLowerCase()
    const inCode = this.codeDrawerTarget?.classList.contains("is-open") && this.monacoHostTarget?.contains(event.target)
    if (inCode || tag === "textarea" || tag === "input" || event.target?.isContentEditable) return
    const key = event.key.toLowerCase()
    if (key === "z" && !event.shiftKey) {
      event.preventDefault()
      this.undo()
    } else if (key === "y" || (key === "z" && event.shiftKey)) {
      event.preventDefault()
      this.redo()
    }
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
    const pending = this.pendingRefresh
    this.pendingRefresh = null
    if (pending?.scrollX != null || pending?.scrollY != null) {
      this.frameWin()?.scrollTo(pending.scrollX || 0, pending.scrollY || 0)
    }
    if (pending?.reselectPath) {
      this.postToFrame({ type: "select-path", path: pending.reselectPath })
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

  onWindowMessage(event) {
    const data = event.data
    if (!data || data.source !== "xbolt-editor") return
    if (data.type === "select") this.applySelection(data)
    if (data.type === "contextmenu") {
      this.applySelection(data)
      this.showContextMenu(data)
    }
    if (data.type === "navigate") this.handleNavigateMessage(data.page)
    if (data.type === "ready") {
      if (this.pendingRefresh?.reselectPath) {
        this.postToFrame({ type: "select-path", path: this.pendingRefresh.reselectPath })
      }
      this.setStatus(this.pendingRefresh?.status || "Ready", this.pendingRefresh?.tone || "")
    }
  }

  postToFrame(payload) {
    this.frameWin()?.postMessage({ source: "xbolt-editor-parent", ...payload }, "*")
  }

  applySelection(data) {
    this.selected = {
      ...this.selected,
      ...data,
      path: data.path || this.selected?.path || null,
      blockPath: data.blockPath || data.path || this.selected?.blockPath || null
    }
    this.element.classList.add("has-inspector")
    if (this.hasBubbleLabelTarget) {
      const tip = (this.selected.path || "").split(" > ").slice(-2).join(" > ")
      this.bubbleLabelTarget.textContent = `${this.selected.tag || "element"}${tip ? ` · ${tip}` : ""}`
    }
    if (this.hasBubbleInputTarget && data.text != null) {
      this.bubbleInputTarget.value = data.text || ""
      this.bubbleInputTarget.disabled = false
    }
    if (data.styles) this.fillStyles(data.styles)
    if (data.attrs) this.fillAttrs(data.attrs)
    this.fillImage(this.selected)
    this.setStatus("Selected", "ok")
  }

  structurePath() {
    return this.selected?.blockPath || this.selected?.path
  }

  fillStyles(styles) {
    this.element.querySelectorAll("[data-style-key]").forEach((input) => {
      const key = input.getAttribute("data-style-key")
      let value = styles[key] || ""
      if (input.type === "color") {
        value = this.toHexColor(value) || "#000000"
      }
      input.value = value
    })
  }

  fillAttrs(attrs) {
    this.element.querySelectorAll("[data-attr-key]").forEach((input) => {
      input.value = attrs[input.getAttribute("data-attr-key")] || ""
    })
    if (this.hasLinkAttrTarget) {
      this.linkAttrTarget.value = this.displayHref(attrs.href || attrs.src || "")
    }
  }

  displayHref(value) {
    const raw = String(value || "")
    if (raw.startsWith("#xbolt-page:")) {
      const page = raw.slice("#xbolt-page:".length)
      if (!page || page === "/") return "index.html"
      return `${page.replace(/^\//, "").replace(/\.html?$/i, "")}.html`
    }
    const prefix = "/dashboard/website/static/assets/"
    if (raw.startsWith(prefix)) return raw.slice(prefix.length)
    return raw
  }

  fillImage(data) {
    if (!this.hasImagePanelTarget) return
    const show = !!data.isImage
    this.imagePanelTarget.hidden = !show
    if (!show) return
    const src = data.attrs?.src || this.extractBgUrl(data.styles?.["background-image"]) || ""
    if (this.hasImageUrlTarget) this.imageUrlTarget.value = src
    if (this.hasImageAltTarget) this.imageAltTarget.value = data.attrs?.alt || ""
    if (this.hasImagePreviewTarget) {
      this.imagePreviewTarget.src = src || ""
      this.imagePreviewTarget.hidden = !src
    }
  }

  extractBgUrl(value) {
    const match = String(value || "").match(/url\((['"]?)(.*?)\1\)/i)
    return match ? match[2] : ""
  }

  toHexColor(value) {
    const v = String(value || "").trim()
    if (/^#[0-9a-f]{3,8}$/i.test(v)) return v.length === 4
      ? `#${v[1]}${v[1]}${v[2]}${v[2]}${v[3]}${v[3]}`
      : v.slice(0, 7)
    const rgb = v.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/i)
    if (!rgb) return ""
    return `#${[rgb[1], rgb[2], rgb[3]].map((n) => Number(n).toString(16).padStart(2, "0")).join("")}`
  }

  openInspector() {
    this.element.classList.add("has-inspector")
  }

  closeInspector() {
    this.element.classList.remove("has-inspector")
  }

  clearSelection({ keepStatus = false } = {}) {
    this.selected = null
    this.closeInspector()
    this.postToFrame({ type: "clear-selection" })
    if (!keepStatus) this.setStatus("Ready")
  }

  doneEditing() {
    this.flushSave().finally(() => this.clearSelection())
  }

  onBubbleInput() {
    if (!this.selected?.path) return
    const value = this.bubbleInputTarget.value
    this.postToFrame({ type: "apply-text", value })
    this.scheduleSave(() =>
      this.patch({
        op: "update_text",
        path: this.staticPathValue,
        element_path: this.selected.path,
        value
      })
    )
  }

  onStyleInput(event) {
    if (!this.selected?.path) return
    const key = event.target.getAttribute("data-style-key")
    if (!key) return
    const value = event.target.value
    this.postToFrame({ type: "apply-styles", styles: { [key]: value } })
    window.clearTimeout(this.styleTimer)
    this.styleTimer = window.setTimeout(() => {
      this.patch({
        op: "update_styles",
        path: this.staticPathValue,
        element_path: this.selected.path,
        styles: { [key]: value }
      }).then(() => this.setStatus("Style saved", "ok"))
        .catch((error) => this.setStatus(error.message || "Save failed", "error"))
    }, 350)
  }

  onAttrInput(event) {
    if (!this.selected?.path) return
    const key = event.target.getAttribute("data-attr-key")
    if (!key) return
    this.patch({
      op: "update_attrs",
      path: this.staticPathValue,
      element_path: this.selected.path,
      attrs: { [key]: event.target.value }
    }).then(() => this.setStatus("Saved", "ok"))
      .catch((error) => this.setStatus(error.message || "Save failed", "error"))
  }

  onLinkAttrInput() {
    if (!this.selected?.path) return
    const tag = this.selected.tag
    const value = this.linkAttrTarget.value
    const attrs = tag === "img" ? { src: value } : { href: value }
    this.patch({
      op: "update_attrs",
      path: this.staticPathValue,
      element_path: this.selected.path,
      attrs
    }).then(() => this.setStatus("Saved", "ok"))
      .catch((error) => this.setStatus(error.message || "Save failed", "error"))
  }

  saveImageUrl() {
    if (!this.selected?.path) return
    this.patch({
      op: "replace_image",
      path: this.staticPathValue,
      element_path: this.selected.path,
      src: this.imageUrlTarget.value,
      alt: this.imageAltTarget?.value
    }).then(() => {
      this.setStatus("Image updated", "ok")
      return this.refreshLive({ reason: "image", reselectPath: this.selected.path, status: "Image updated", tone: "ok" })
    }).catch((error) => this.setStatus(error.message || "Save failed", "error"))
  }

  async uploadImage(event) {
    const file = event.target.files?.[0]
    if (!file || !this.selected?.path) return
    const body = new FormData()
    body.append("path", this.staticPathValue)
    body.append("element_path", this.selected.path)
    body.append("file", file)
    body.append("alt", this.imageAltTarget?.value || "")
    this.setStatus("Uploading…", "saving")
    try {
      const response = await fetch(this.staticUploadUrlValue, {
        method: "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken() },
        body
      })
      const payload = await response.json()
      if (!response.ok) throw new Error(payload.message || "Upload failed")
      this.setHistoryFlags(payload)
      if (this.hasImageUrlTarget) this.imageUrlTarget.value = payload.src || ""
      if (this.hasImagePreviewTarget) this.imagePreviewTarget.src = payload.src || ""
      await this.refreshLive({ reason: "image", reselectPath: this.selected.path, status: "Image uploaded", tone: "ok" })
    } catch (error) {
      this.setStatus(error.message || "Upload failed", "error")
    } finally {
      event.target.value = ""
    }
  }

  saveNow() {
    this.flushSave({ keepOpen: true })
  }

  scheduleSave(fn) {
    this.setStatus("Saving…", "saving")
    window.clearTimeout(this.saveTimer)
    this.saveTimer = window.setTimeout(() => {
      Promise.resolve(fn())
        .then(() => this.setStatus("Saved", "ok"))
        .catch((error) => this.setStatus(error.message || "Save failed", "error"))
    }, 450)
  }

  flushSave({ keepOpen = false } = {}) {
    window.clearTimeout(this.saveTimer)
    if (!this.selected?.path || !this.hasBubbleInputTarget) return Promise.resolve()
    this.setStatus("Saving…", "saving")
    return this.patch({
      op: "update_text",
      path: this.staticPathValue,
      element_path: this.selected.path,
      value: this.bubbleInputTarget.value
    })
      .then(() => {
        this.setStatus("Saved", "ok")
        if (!keepOpen) this.clearSelection({ keepStatus: true })
      })
      .catch((error) => this.setStatus(error.message || "Save failed", "error"))
  }

  // --- Context menu --------------------------------------------------------

  showContextMenu(data) {
    if (!this.hasContextMenuTarget) return
    const frameRect = this.frameTarget.getBoundingClientRect()
    const x = frameRect.left + (data.x || 0)
    const y = frameRect.top + (data.y || 0)
    this.contextMenuTarget.hidden = false
    this.contextMenuTarget.style.left = `${Math.min(x, window.innerWidth - 220)}px`
    this.contextMenuTarget.style.top = `${Math.min(y, window.innerHeight - 320)}px`
    this.contextMenuTarget.querySelector('[data-ctx="replace-image"]')?.toggleAttribute("hidden", !data.isImage)
  }

  hideContextMenu() {
    if (this.hasContextMenuTarget) this.contextMenuTarget.hidden = true
  }

  onDocumentClick(event) {
    if (this.hasPageMenuTarget && !this.pageMenuTarget.hasAttribute("hidden")) {
      if (!event.target.closest?.(".xb-page-menu") && !event.target.closest?.("[data-action*='togglePages']")) {
        this.hidePageMenu()
      }
    }
    if (this.hasContextMenuTarget && !this.contextMenuTarget.hasAttribute("hidden")) {
      if (!event.target.closest?.(".xb-ctx-menu")) this.hideContextMenu()
    }
  }

  async onContextAction(event) {
    const btn = event.target.closest("[data-ctx]")
    if (!btn || !this.selected?.path) return
    const action = btn.getAttribute("data-ctx")
    this.hideContextMenu()
    const path = this.selected.path
    const blockPath = this.structurePath()

    try {
      if (action === "edit-text" || action === "edit-styles") {
        this.openInspector()
        if (action === "edit-text") this.bubbleInputTarget?.focus()
        return
      }
      if (action === "edit-html" || action === "open-code") {
        await this.openCodeFocused(path)
        return
      }
      if (action === "duplicate") {
        await this.runStructureOp("duplicate", { op: "duplicate", path: this.staticPathValue, element_path: blockPath }, "Duplicated")
        return
      }
      if (action === "delete") {
        const ok = await this.askConfirm("Delete this element from the live site? You can undo afterwards.", {
          title: "Delete element?",
          confirmLabel: "Delete"
        })
        if (!ok) return
        await this.runStructureOp("delete", { op: "delete", path: this.staticPathValue, element_path: blockPath }, "Deleted", {
          clearSelection: true
        })
        return
      }
      if (action === "move-up" || action === "move-down") {
        await this.runStructureOp(
          "move",
          {
            op: "move",
            path: this.staticPathValue,
            element_path: blockPath,
            direction: action === "move-up" ? "up" : "down"
          },
          "Moved",
          { reselectPath: blockPath }
        )
        return
      }
      if (action === "wrap") {
        await this.runStructureOp(
          "wrap",
          { op: "wrap", path: this.staticPathValue, element_path: blockPath, tag: "section" },
          "Wrapped"
        )
        return
      }
      if (action === "replace-image") {
        this.openInspector()
        this.imagePanelTarget?.removeAttribute("hidden")
        return
      }
      if (action === "copy-html") {
        await navigator.clipboard.writeText(this.selected.html || "")
        this.setStatus("HTML copied", "ok")
        return
      }
      if (action === "copy-css") {
        const styles = this.selected.styles || {}
        const body = Object.entries(styles)
          .filter(([, v]) => v && v !== "none" && v !== "normal" && v !== "auto")
          .map(([k, v]) => `  ${k}: ${v};`)
          .join("\n")
        await navigator.clipboard.writeText(`${this.selected.tag || "element"} {\n${body}\n}`)
        this.setStatus("CSS copied", "ok")
      }
    } catch (error) {
      this.setStatus(error.message || "Action failed", "error")
    }
  }

  async runStructureOp(reason, body, status, { reselectPath = null, clearSelection = false } = {}) {
    if (this.busy) return
    this.busy = true
    this.setStatus(`${status}…`, "saving")
    try {
      await this.patch(body)
      if (clearSelection) this.clearSelection({ keepStatus: true })
      await this.refreshLive({ reason, reselectPath, status, tone: "ok" })
    } catch (error) {
      this.setStatus(error.message || "Action failed", "error")
    } finally {
      this.busy = false
    }
  }

  // --- Pages / navigation --------------------------------------------------

  togglePages(event) {
    event?.preventDefault()
    event?.stopPropagation()
    if (!this.hasPageMenuTarget) return
    if (this.pageMenuTarget.hasAttribute("hidden")) {
      const rect = this.pagesBtnTarget?.getBoundingClientRect?.()
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

  switchPageLink(event) {
    event.preventDefault()
    const path = event.currentTarget.getAttribute("data-path")
    const page = this.pagesList().find((entry) => entry.path === path)
    if (page) this.openEditorPage(page)
  }

  handleNavigateMessage(raw) {
    const page = this.resolveEditorPage(raw)
    if (!page) {
      this.setStatus("No matching page", "error")
      return
    }
    this.openEditorPage(page)
  }

  async openEditorPage(page) {
    if (!page?.path) return
    if (this.codeDirty) {
      const ok = await this.askConfirm("You have unsaved code changes. Discard them and switch pages?", {
        title: "Discard code changes?",
        confirmLabel: "Discard"
      })
      if (!ok) return
    }
    this.hidePageMenu()
    this.staticPathValue = page.path
    this.previewUrlValue = this.previewUrlFor(page.path)
    try {
      window.history.replaceState({}, "", page.url)
    } catch {
      /* ignore */
    }
    document.querySelectorAll(".xb-page-link").forEach((node) => {
      node.classList.toggle("is-current", node.getAttribute("data-path") === page.path)
    })
    this.codeDirty = false
    this.setStatus(`Opening ${page.title || page.path}…`, "saving")
    await this.refreshLive({ reason: "navigate", status: `Editing ${page.title || page.path}`, tone: "ok" })
    await this.loadSource({ quiet: true })
  }

  resolveEditorPage(href) {
    if (!href) return null
    let raw = href.trim()
    if (!raw || raw.startsWith("mailto:") || raw.startsWith("tel:") || raw.startsWith("javascript:")) return null
    if (raw.startsWith("#xbolt-page:")) raw = raw.slice("#xbolt-page:".length)
    else if (raw.startsWith("#")) return null
    if (raw.startsWith("/") && !raw.includes("://") && !raw.includes(".html")) {
      return this.pagesList().find((page) => page.path === raw) || null
    }
    let path = raw
    try {
      if (/^https?:\/\//i.test(raw) || raw.startsWith("//")) {
        const url = new URL(raw, window.location.origin)
        path = url.pathname
      }
    } catch {
      return null
    }
    path = path.split("?")[0].split("#")[0].replace(/^\.\//, "")
    if (!path.startsWith("/")) path = `/${path}`
    if (path.endsWith("/index.html") || path.endsWith("/index.htm")) path = path.replace(/\/index\.html?$/i, "") || "/"
    if (/\.html?$/i.test(path)) path = path.replace(/\.html?$/i, "") || "/"
    if (path !== "/" && path.endsWith("/")) path = path.slice(0, -1)
    if (path === "/index") path = "/"
    return this.pagesList().find((page) => page.path === path) || null
  }

  reloadPreview() {
    return this.refreshLive({ reason: "refresh", status: "Ready" })
  }

  refreshLive({ reason = "", reselectPath = null, status = "Ready", tone = "" } = {}) {
    if (!this.hasFrameTarget) return Promise.resolve()
    const win = this.frameWin()
    const url = `${this.previewUrlFor(this.staticPathValue)}&t=${Date.now()}`
    this.pendingRefresh = {
      reason,
      reselectPath,
      scrollX: win?.scrollX || 0,
      scrollY: win?.scrollY || 0,
      status,
      tone,
      keepSelection: !!reselectPath
    }
    this.setStatus(reason === "refresh" ? "Refreshing…" : "Updating…", "saving")
    return new Promise((resolve) => {
      this.refreshResolver = resolve
      this.frameTarget.src = url
      window.setTimeout(() => {
        if (this.refreshResolver === resolve) {
          this.refreshResolver = null
          resolve()
        }
      }, 12000)
    }).then(() => this.loadSource({ quiet: true }))
  }

  // --- Undo ----------------------------------------------------------------

  async undo() {
    this.setStatus("Undoing…", "saving")
    try {
      const response = await fetch(this.staticUndoUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ path: this.staticPathValue })
      })
      const payload = await response.json()
      if (!response.ok) throw new Error(payload.message || "Undo failed")
      this.setHistoryFlags(payload)
      await this.refreshLive({ reason: "undo", status: "Undone", tone: "ok" })
    } catch (error) {
      this.setStatus(error.message || "Undo failed", "error")
    }
  }

  async redo() {
    if (!this.staticRedoUrlValue) return
    this.setStatus("Redoing…", "saving")
    try {
      const response = await fetch(this.staticRedoUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ path: this.staticPathValue })
      })
      const payload = await response.json()
      if (!response.ok) throw new Error(payload.message || "Redo failed")
      this.setHistoryFlags(payload)
      await this.refreshLive({ reason: "redo", status: "Redone", tone: "ok" })
    } catch (error) {
      this.setStatus(error.message || "Redo failed", "error")
    }
  }

  setCanUndo(value) {
    this.setHistoryFlags({ can_undo: value, can_redo: this.canRedo })
  }

  setHistoryFlags(payload = {}) {
    this.canUndo = !!payload.can_undo
    this.canRedo = !!payload.can_redo
    if (this.hasUndoBtnTarget) this.undoBtnTarget.disabled = !this.canUndo
    if (this.hasRedoBtnTarget) this.redoBtnTarget.disabled = !this.canRedo
  }

  // --- Code / Monaco -------------------------------------------------------

  toggleCode() {
    if (!this.hasCodeDrawerTarget) return
    const open = !this.codeDrawerTarget.classList.contains("is-open")
    this.codeDrawerTarget.classList.toggle("is-open", open)
    this.codeBtnTarget?.classList.toggle("is-active", open)
    if (open) {
      this.loadSource()
        .then(() => this.ensureCodeEditor())
        .then(() => this.renderCodeContent())
        .then(() => this.layoutCodeEditor())
        .catch((error) => this.setStatus(error.message || "Code editor failed", "error"))
    }
  }

  switchCodeTab(event) {
    const tab = event.currentTarget.getAttribute("data-code-tab")
    if (!tab || tab === this.codeTab) return
    this.applyCodeTab(tab)
  }

  applyCodeTab(tab) {
    this.codeTab = tab
    this.element.querySelectorAll(".xb-code-tab").forEach((node) => {
      node.classList.toggle("is-active", node.getAttribute("data-code-tab") === tab)
    })
    this.syncCodeSourcesVisibility()
    this.renderCodeContent()
    this.layoutCodeEditor()
  }

  syncCodeSourcesVisibility() {
    const showSources = this.codeTab === "css"
    if (this.hasCssSourcesTarget) this.cssSourcesTarget.hidden = !showSources
    if (this.hasCodeBodyTarget) this.codeBodyTarget.classList.toggle("has-sources", showSources)
  }

  async loadSource({ quiet = false } = {}) {
    if (!this.staticSourceUrlValue) return
    if (!quiet) this.setStatus("Loading source…", "saving")
    try {
      const url = `${this.staticSourceUrlValue}?path=${encodeURIComponent(this.staticPathValue)}&t=${Date.now()}`
      const response = await fetch(url, {
        headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest" },
        credentials: "same-origin",
        cache: "no-store"
      })
      const payload = await response.json()
      if (!response.ok) throw new Error(payload.message || "Could not load source")
      this.sourcePayload = payload
      this.setHistoryFlags(payload)
      this.renderCssSources()
      if (this.codeDrawerTarget?.classList.contains("is-open")) {
        await this.ensureCodeEditor()
        this.renderCodeContent()
        this.layoutCodeEditor()
      }
      if (!quiet) this.setStatus("Ready")
    } catch (error) {
      if (!quiet) this.setStatus(error.message || "Source load failed", "error")
    }
  }

  reloadSource() {
    this.codeDirty = false
    return this.loadSource()
  }

  renderCssSources() {
    if (!this.hasCssSourcesTarget) return
    const sources = this.sourcePayload?.css_sources || []
    if (!this.activeCssSourceId && sources[0]) this.activeCssSourceId = sources[0].id
    this.cssSourcesTarget.innerHTML = sources
      .map(
        (source) =>
          `<button type="button" class="xb-code-source ${source.id === this.activeCssSourceId ? "is-active" : ""}" data-source-id="${source.id}">${this.escapeHtml(source.label)}</button>`
      )
      .join("")
    this.cssSourcesTarget.querySelectorAll("[data-source-id]").forEach((btn) => {
      btn.addEventListener("click", () => {
        this.activeCssSourceId = btn.getAttribute("data-source-id")
        this.renderCssSources()
        this.renderCodeContent()
      })
    })
  }

  escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
  }

  onCodeFallbackInput() {
    this.codeDirty = true
  }

  async ensureCodeEditor() {
    if (this.monacoReady || this.useCodeFallback) return
    try {
      await this.ensureMonaco()
      this.monacoReady = true
      this.useCodeFallback = false
      if (this.hasMonacoHostTarget) this.monacoHostTarget.hidden = false
      if (this.hasCodeFallbackTarget) this.codeFallbackTarget.hidden = true
    } catch (error) {
      console.warn("Monaco unavailable, using fallback editor", error)
      this.useCodeFallback = true
      if (this.hasMonacoHostTarget) this.monacoHostTarget.hidden = true
      if (this.hasCodeFallbackTarget) this.codeFallbackTarget.hidden = false
    }
  }

  ensureMonaco() {
    if (this.monacoEditor) return Promise.resolve()
    return new Promise((resolve, reject) => {
      if (!window.require) {
        reject(new Error("Monaco loader missing"))
        return
      }
      const timer = window.setTimeout(() => reject(new Error("Monaco load timed out")), 8000)
      window.MonacoEnvironment = {
        getWorker() {
          return {
            postMessage() {},
            addEventListener() {},
            removeEventListener() {},
            terminate() {}
          }
        }
      }
      window.require.config({ paths: { vs: "https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/min/vs" } })
      window.require(
        ["vs/editor/editor.main"],
        () => {
          window.clearTimeout(timer)
          this.monaco = window.monaco
          this.monacoEditor = this.monaco.editor.create(this.monacoHostTarget, {
            value: "",
            language: "html",
            theme: "vs-dark",
            automaticLayout: true,
            minimap: { enabled: false },
            fontSize: 13,
            wordWrap: "on",
            scrollBeyondLastLine: false
          })
          this.monacoEditor.onDidChangeModelContent(() => {
            this.codeDirty = true
          })
          resolve()
        },
        (err) => {
          window.clearTimeout(timer)
          reject(err || new Error("Monaco failed to load"))
        }
      )
    })
  }

  currentCodeValue() {
    if (this.useCodeFallback && this.hasCodeFallbackTarget) return this.codeFallbackTarget.value
    if (this.monacoEditor) return this.monacoEditor.getValue()
    return ""
  }

  renderCodeContent() {
    if (!this.sourcePayload) return
    this.syncCodeSourcesVisibility()
    let value = ""
    if (this.codeTab === "html") {
      value = this.sourcePayload.html || ""
      if (this.monacoEditor) {
        this.monaco.editor.setModelLanguage(this.monacoEditor.getModel(), "html")
        this.monacoEditor.setValue(value)
      }
    } else {
      const source =
        (this.sourcePayload.css_sources || []).find((entry) => entry.id === this.activeCssSourceId) ||
        (this.sourcePayload.css_sources || [])[0]
      this.activeCssSourceId = source?.id || null
      value = source?.content || "/* No local CSS sources on this page */\n"
      if (this.monacoEditor) {
        this.monaco.editor.setModelLanguage(this.monacoEditor.getModel(), "css")
        this.monacoEditor.setValue(value)
      }
    }
    if (this.useCodeFallback && this.hasCodeFallbackTarget) {
      this.codeFallbackTarget.value = value
    }
    this.codeDirty = false
  }

  layoutCodeEditor() {
    window.setTimeout(() => {
      try {
        this.monacoEditor?.layout()
      } catch {
        /* ignore */
      }
    }, 220)
  }

  async openCodeFocused(path) {
    if (!this.codeDrawerTarget.classList.contains("is-open")) {
      this.codeDrawerTarget.classList.add("is-open")
      this.codeBtnTarget?.classList.add("is-active")
    }
    await this.loadSource()
    await this.ensureCodeEditor()
    this.applyCodeTab("html")
    const html = this.selected?.html
    if (html && this.monacoEditor && !this.useCodeFallback) {
      const full = this.monacoEditor.getValue()
      const snippet = html.slice(0, Math.min(html.length, 120))
      const index = full.indexOf(snippet)
      if (index >= 0) {
        const start = this.monacoEditor.getModel().getPositionAt(index)
        this.monacoEditor.revealPositionInCenter(start)
        this.monacoEditor.setPosition(start)
      }
    }
    this.setStatus(path ? `Code · ${path}` : "Code", "ok")
  }

  async applyCode() {
    await this.ensureCodeEditor()
    const value = this.currentCodeValue()
    if (!value) {
      this.setStatus("Nothing to apply", "error")
      return
    }
    this.setStatus("Applying code…", "saving")
    try {
      if (this.codeTab === "html") {
        await this.patch({ op: "save_html", path: this.staticPathValue, html: value })
      } else {
        await this.patch({
          op: "save_css",
          path: this.staticPathValue,
          source_id: this.activeCssSourceId,
          css: value
        })
      }
      this.codeDirty = false
      await this.refreshLive({ reason: "code", status: "Code applied", tone: "ok" })
    } catch (error) {
      this.setStatus(error.message || "Apply failed", "error")
    }
  }

  patch(body) {
    return fetch(this.staticUpdateUrlValue, {
      method: "PATCH",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken(),
        "X-Requested-With": "XMLHttpRequest"
      },
      body: JSON.stringify(body)
    }).then(async (response) => {
      let payload = {}
      try {
        payload = await response.json()
      } catch {
        payload = {}
      }
      if (!response.ok) throw new Error(payload.message || `Save failed (${response.status})`)
      this.setHistoryFlags(payload)
      return payload
    })
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
}
