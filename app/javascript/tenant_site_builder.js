const FIELD_LABELS = {
  eyebrow: "Eyebrow",
  heading: "Heading",
  subheading: "Subheading",
  body: "Body text",
  button_text: "Button text",
  title: "Card title",
  subtitle: "Card subtitle",
  name: "Name",
  role: "Role",
  quote: "Quote",
  question: "Question",
  answer: "Answer"
}

function escapeHtml(value) {
  return String(value || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;")
}

function parseJson(value, fallback) {
  try {
    const parsed = JSON.parse(value || "")
    return parsed || fallback
  } catch (_) {
    return fallback
  }
}

function initBuilder() {
  const root = document.getElementById("tenant-builder")
  if (!root || root.dataset.initialized === "true") return
  root.dataset.initialized = "true"

  const frame = document.getElementById("tenant-builder-frame")
  const status = document.getElementById("tenant-builder-save-status")
  const pageSwitcher = document.getElementById("tenant-builder-page-switcher")
  const emptyState = document.getElementById("tenant-builder-empty-state")
  const fieldPanel = document.getElementById("tenant-builder-field-panel")
  const fieldLabel = document.getElementById("tenant-builder-field-label")
  const fieldMeta = document.getElementById("tenant-builder-field-meta")
  const textInput = document.getElementById("tenant-builder-text-input")
  const clearSelectionBtn = document.getElementById("tenant-builder-clear-selection")
  const publishBtn = document.getElementById("tenant-builder-publish")
  const staticMode = root.dataset.staticMode === "true"
  let sections = parseJson(root.dataset.sections, [])
  let selected = null
  let selectedElement = null
  let saveTimer = null
  let sortables = []

  function csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  function setStatus(message, tone = "muted") {
    if (!status) return
    status.textContent = message
    status.className = "text-[11px] " + (tone === "error" ? "text-red-500" : tone === "saving" ? "text-amber-600" : "text-zinc-400")
  }

  function selectedPathFromElement(element) {
    if (staticMode) {
      const rawTextIndex = element.dataset.xboltTextIndex
      if (!rawTextIndex) return null

      const textIndex = rawTextIndex.match(/^\d+$/) ? Number(rawTextIndex) : rawTextIndex
      return { textIndex }
    }

    const sectionIndex = Number(element.dataset.xboltSectionIndex)
    const field = element.dataset.xboltField
    const itemKey = element.dataset.xboltItemKey
    const itemIndex = element.dataset.xboltItemIndex

    if (!Number.isInteger(sectionIndex) || !field) return null

    return {
      sectionIndex,
      field,
      itemKey: itemKey || null,
      itemIndex: itemIndex === undefined || itemIndex === "" ? null : Number(itemIndex)
    }
  }

  function getSelectedValue(path) {
    if (staticMode) return selectedElement?.textContent || ""

    const section = sections[path.sectionIndex]
    if (!section) return ""

    if (path.itemKey) {
      const item = section[path.itemKey]?.[path.itemIndex]
      return item?.[path.field] || ""
    }

    return section[path.field] || ""
  }

  function setSelectedValue(path, value) {
    if (staticMode) return

    const section = sections[path.sectionIndex]
    if (!section) return

    if (path.itemKey) {
      section[path.itemKey] ||= []
      section[path.itemKey][path.itemIndex] ||= {}
      section[path.itemKey][path.itemIndex][path.field] = value
      return
    }

    section[path.field] = value
  }

  function saveNow({ reload = false, throwOnError = false } = {}) {
    window.clearTimeout(saveTimer)
    setStatus("Saving...", "saving")

    if (staticMode) {
      if (!selected) {
        setStatus("Saved")
        return Promise.resolve()
      }

      return fetch(root.dataset.staticUpdateUrl, {
        method: "PATCH",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken()
        },
        body: JSON.stringify({
          path: root.dataset.staticPath,
          text_index: selected.textIndex,
          value: textInput?.value || ""
        })
      })
        .then((response) => response.ok ? response.json() : response.json().then((payload) => Promise.reject(payload)))
        .then(() => {
          setStatus("Saved")
          if (reload) reloadFrame()
        })
        .catch((error) => {
          setStatus(error?.message || "Save failed", "error")
          if (throwOnError) throw error
        })
    }

    return fetch(root.dataset.updateUrl, {
      method: "PATCH",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken()
      },
      body: JSON.stringify({
        tenant_site_page: {
          title: root.dataset.pageTitle,
          slug: root.dataset.pageSlug,
          position: root.dataset.pagePosition,
          sections_json: JSON.stringify(sections)
        }
      })
    })
      .then((response) => response.ok ? response.json() : response.json().then((payload) => Promise.reject(payload)))
      .then(() => {
        setStatus("Saved")
        if (reload) reloadFrame()
      })
      .catch((error) => {
        setStatus(error?.message || "Save failed", "error")
        if (throwOnError) throw error
      })
  }

  function scheduleSave() {
    setStatus("Saving...", "saving")
    window.clearTimeout(saveTimer)
    saveTimer = window.setTimeout(() => saveNow(), 450)
  }

  function reloadFrame() {
    if (!frame) return
    frame.src = root.dataset.previewUrl + (root.dataset.previewUrl.includes("?") ? "&" : "?") + "t=" + Date.now()
  }

  function clearSelection() {
    selectedElement?.removeAttribute("data-xbolt-selected")
    selectedElement = null
    selected = null
    emptyState?.classList.remove("hidden")
    fieldPanel?.classList.add("hidden")
    if (textInput) textInput.value = ""
  }

  function selectElement(element) {
    const path = selectedPathFromElement(element)
    if (!path) return

    selectedElement?.removeAttribute("data-xbolt-selected")
    selectedElement = element
    selectedElement.setAttribute("data-xbolt-selected", "true")
    selected = path

    const section = staticMode ? {} : (sections[path.sectionIndex] || {})
    const label = staticMode ? "Selected text" : (FIELD_LABELS[path.field] || path.field)
    const scope = staticMode ? staticScopeLabel(path.textIndex) : (path.itemKey ? `${section.type || "item"} item ${path.itemIndex + 1}` : `${section.type || "section"} section`)

    if (fieldLabel) fieldLabel.textContent = label
    if (fieldMeta) fieldMeta.textContent = scope.replace("_", " ")
    if (textInput) textInput.value = getSelectedValue(path)
    emptyState?.classList.add("hidden")
    fieldPanel?.classList.remove("hidden")
    textInput?.focus()
  }

  function staticScopeLabel(textIndex) {
    if (typeof textIndex === "string" && textIndex.startsWith("review:")) {
      const parts = textIndex.split(":")
      return `Review ${Number(parts[1]) + 1} ${parts[2] || "text"}`
    }

    return `Text ${Number(textIndex) + 1}`
  }

  function bindFrame() {
    const doc = frame?.contentDocument
    if (!doc) return

    clearSelection()
    sortables.forEach((sortable) => sortable.destroy())
    sortables = []

    doc.addEventListener("click", (event) => {
      const editable = event.target.closest("[data-xbolt-editable]")
      event.preventDefault()
      event.stopPropagation()
      if (editable) selectElement(editable)
    }, true)

    doc.querySelectorAll("a, button, input, textarea, select").forEach((element) => {
      if (!element.matches("[data-xbolt-editable]")) {
        element.addEventListener("click", (event) => {
          event.preventDefault()
          event.stopPropagation()
        }, true)
      }
    })

    if (window.Sortable) {
      const sectionParent = doc.querySelector("main")
      if (sectionParent) {
        sortables.push(window.Sortable.create(sectionParent, {
          draggable: "[data-xbolt-section]",
          ghostClass: "xbolt-drag-ghost",
          animation: 150,
          onEnd: (event) => {
            if (event.oldIndex === event.newIndex) return
            if (staticMode) {
              if (String(event.from.dataset.xboltContainerIndex) === "dynamic-reviews") {
                setStatus("Review order editing is not available for loaded review scripts yet", "error")
                reloadFrame()
                return
              }

              saveStaticReorder({
                containerIndex: Number(event.from.dataset.xboltContainerIndex || 0),
                oldIndex: event.oldIndex,
                newIndex: event.newIndex
              })
              return
            }

            const moved = sections.splice(event.oldIndex, 1)[0]
            sections.splice(event.newIndex, 0, moved)
            saveNow({ reload: true })
          }
        }))
      }

      doc.querySelectorAll("[data-xbolt-items]").forEach((container) => {
        sortables.push(window.Sortable.create(container, {
          draggable: "[data-xbolt-item]",
          ghostClass: "xbolt-drag-ghost",
          animation: 150,
          onEnd: (event) => {
            if (event.oldIndex === event.newIndex) return
            if (staticMode) {
              saveStaticReorder({
                containerIndex: Number(container.dataset.xboltContainerIndex || 0),
                oldIndex: event.oldIndex,
                newIndex: event.newIndex
              })
              return
            }

            const sectionIndex = Number(container.dataset.xboltSectionIndex)
            const itemKey = container.dataset.xboltItemKey
            const items = sections[sectionIndex]?.[itemKey]
            if (!Array.isArray(items)) return

            const moved = items.splice(event.oldIndex, 1)[0]
            items.splice(event.newIndex, 0, moved)
            saveNow({ reload: true })
          }
        }))
      })
    }
  }

  function saveStaticReorder({ containerIndex, oldIndex, newIndex }) {
    setStatus("Saving...", "saving")
    return fetch(root.dataset.staticUpdateUrl, {
      method: "PATCH",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken()
      },
      body: JSON.stringify({
        path: root.dataset.staticPath,
        reorder: {
          container_index: containerIndex,
          old_index: oldIndex,
          new_index: newIndex
        }
      })
    })
      .then((response) => response.ok ? response.json() : response.json().then((payload) => Promise.reject(payload)))
      .then(() => {
        setStatus("Saved")
        reloadFrame()
      })
      .catch((error) => setStatus(error?.message || "Save failed", "error"))
  }

  textInput?.addEventListener("input", () => {
    if (!selected || !selectedElement) return

    const value = textInput.value
    setSelectedValue(selected, value)
    selectedElement.textContent = value
    scheduleSave()
  })

  clearSelectionBtn?.addEventListener("click", clearSelection)

  pageSwitcher?.addEventListener("change", () => {
    if (pageSwitcher.value) window.location.href = pageSwitcher.value
  })

  publishBtn?.addEventListener("click", () => {
    if (staticMode) return

    setStatus("Publishing...", "saving")
    saveNow({ throwOnError: true })
      .then(() => fetch(root.dataset.publishUrl, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken()
        },
        body: JSON.stringify({})
      }))
      .then((response) => response.ok ? response.json() : response.json().then((payload) => Promise.reject(payload)))
      .then((payload) => setStatus(payload.message || "Published"))
      .catch((error) => setStatus(error?.message || "Publish failed", "error"))
  })

  frame?.addEventListener("load", bindFrame)

  setStatus("Saved")
}

document.addEventListener("DOMContentLoaded", initBuilder)
document.addEventListener("turbo:load", initBuilder)
