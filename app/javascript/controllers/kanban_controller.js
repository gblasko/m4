import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["column"]

  connect() {
    this.sortables = this.columnTargets.map((col) => {
      return Sortable.create(col, {
        group: "kanban",
        animation: 150,
        ghostClass: "opacity-30",
        dragClass: "rotate-2",
        onAdd: (event) => this.handleMove(event),
        onUpdate: () => {} // reorder within same column — no API call needed
      })
    })
  }

  disconnect() {
    this.sortables?.forEach((s) => s.destroy())
    this.sortables = null
  }

  async handleMove(event) {
    const card = event.item
    const toStatus = event.to.dataset.kanbanStatus
    const fromStatus = event.from.dataset.kanbanStatus
    const requestId = card.dataset.requestId

    if (!toStatus || !requestId || toStatus === fromStatus) return

    // Mark this tab so the realtime listener skips a reload it'll provoke
    window.__kanbanOptimistic = Date.now()

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    try {
      const res = await fetch(`/requests/${requestId}/status?to=${toStatus}`, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": csrf,
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        },
        credentials: "same-origin"
      })

      if (!res.ok) {
        const body = await res.json().catch(() => ({}))
        this.revert(event)
        this.toast(body.error || "Move failed", "error")
        return
      }

      this.toast("Updated", "ok")
      this.updateCounts()
    } catch (err) {
      this.revert(event)
      this.toast("Network error — undoing move", "error")
    }
  }

  revert(event) {
    // Put the card back where it came from
    if (event.from && event.item) {
      event.from.insertBefore(event.item, event.from.children[event.oldIndex] || null)
    }
    this.updateCounts()
  }

  updateCounts() {
    this.columnTargets.forEach((col) => {
      const count = col.querySelectorAll("[data-request-id]").length
      const badge = col.parentElement.querySelector("[data-kanban-count]")
      if (badge) badge.textContent = count
    })
  }

  toast(msg, kind) {
    const el = document.createElement("div")
    el.textContent = msg
    el.className =
      "fixed bottom-4 right-4 z-50 px-3 py-2 rounded-lg shadow-lg text-sm font-medium text-white " +
      (kind === "error" ? "bg-rose-600" : "bg-slate-900")
    document.body.appendChild(el)
    setTimeout(() => el.remove(), 2200)
  }
}
