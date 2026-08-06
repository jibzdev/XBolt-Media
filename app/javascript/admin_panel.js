import { Turbo } from "@hotwired/turbo-rails"

const state = { navListenersBound: false, shellListenersBound: false, sidebarOpen: false }

function clearLoadingState() {
  document.getElementById("admin-main")?.classList.remove("admin-main--loading")
}

function bindAdminNavListeners() {
  if (state.navListenersBound) return
  state.navListenersBound = true

  document.addEventListener("turbo:before-visit", () => {
    document.getElementById("admin-main")?.classList.add("admin-main--loading")
  })

  document.addEventListener("turbo:render", clearLoadingState)
  document.addEventListener("turbo:load", clearLoadingState)
  document.addEventListener("turbo:before-render", clearLoadingState)
  document.addEventListener("turbo:fetch-request-error", clearLoadingState)
  document.addEventListener("turbo:submit-end", clearLoadingState)
  window.addEventListener("pageshow", clearLoadingState)
}

function setSidebarOpen(open) {
  const sidebar = document.getElementById("sidebar")
  const overlay = document.getElementById("admin-sidebar-overlay")
  if (!sidebar || !overlay) return

  state.sidebarOpen = open

  sidebar.classList.toggle("-translate-x-full", !open)
  sidebar.classList.toggle("translate-x-0", open)
  overlay.classList.toggle("opacity-0", !open)
  overlay.classList.toggle("opacity-100", open)
  overlay.classList.toggle("pointer-events-none", !open)
  overlay.classList.toggle("pointer-events-auto", open)
  overlay.setAttribute("aria-hidden", open ? "false" : "true")
  document.body.style.overflow = open ? "hidden" : ""
}

function closeSidebar() {
  setSidebarOpen(false)
}

function bindAdminShellListeners() {
  if (state.shellListenersBound) return
  state.shellListenersBound = true

  document.addEventListener("click", (event) => {
    if (event.target.closest("#open-admin-sidebar")) {
      event.preventDefault()
      setSidebarOpen(true)
      return
    }

    if (event.target.closest("#close-admin-sidebar") || event.target.closest("#admin-sidebar-overlay")) {
      event.preventDefault()
      closeSidebar()
      return
    }

    if (window.innerWidth < 1024 && state.sidebarOpen && event.target.closest("#sidebar a")) {
      closeSidebar()
    }
  })

  window.addEventListener("resize", () => {
    if (window.innerWidth >= 1024) closeSidebar()
  })

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") closeSidebar()
  })
}

export function initAdminShell() {
  if (!document.getElementById("admin-app-shell")) return

  try {
    if (Turbo.config?.drive) {
      Turbo.config.drive.progressBarDelay = 0
    }
  } catch (_) {
    /* noop */
  }

  bindAdminNavListeners()
  bindAdminShellListeners()
  closeSidebar()
  clearLoadingState()

  createLucideIcons()
}

document.addEventListener("DOMContentLoaded", initAdminShell)
document.addEventListener("turbo:load", initAdminShell)
document.addEventListener("turbo:render", initAdminShell)
window.addEventListener("load", initAdminShell)

function createLucideIcons(attempt = 0) {
  if (window.lucide && typeof window.lucide.createIcons === "function") {
    window.lucide.createIcons()
    return
  }

  if (attempt < 20) {
    window.setTimeout(() => createLucideIcons(attempt + 1), 100)
  }
}
