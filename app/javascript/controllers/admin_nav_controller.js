import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "backdrop", "toggle"]

  connect() {
    this.mediaQuery = window.matchMedia("(min-width: 1024px)")
    this.mediaQuery.addEventListener("change", this.updateLayout)
    this.updateLayout()
  }

  disconnect() {
    this.mediaQuery.removeEventListener("change", this.updateLayout)
  }

  open() {
    if (this.mediaQuery.matches) return

    this.sidebarTarget.classList.remove("-translate-x-full")
    this.sidebarTarget.removeAttribute("inert")
    this.backdropTarget.classList.remove("hidden")
    this.toggleTarget.setAttribute("aria-expanded", "true")
    this.sidebarTarget.querySelector("a, button, select")?.focus()
  }

  close(event) {
    if (this.mediaQuery.matches) return

    this.sidebarTarget.classList.add("-translate-x-full")
    this.sidebarTarget.setAttribute("inert", "")
    this.backdropTarget.classList.add("hidden")
    this.toggleTarget.setAttribute("aria-expanded", "false")
    if (event) this.toggleTarget.focus()
  }

  updateLayout = () => {
    if (this.mediaQuery.matches) {
      this.sidebarTarget.classList.remove("-translate-x-full")
      this.sidebarTarget.removeAttribute("inert")
      this.backdropTarget.classList.add("hidden")
      this.toggleTarget.setAttribute("aria-expanded", "false")
    } else {
      this.close()
    }
  }
}
