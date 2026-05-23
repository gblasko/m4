import { Controller } from "@hotwired/stimulus"

// Stimulus controller backing the customer request "Date + Time" picker.
// - On date change, fetches /locations/:id/availability and rerenders slot chips.
// - On chip click, populates the hidden `request[scheduled_for]` field.
export default class extends Controller {
  static targets = ["date", "slots", "selected", "hint"]
  static values = {
    locationId: Number,
    step: { type: Number, default: 30 }
  }

  connect() {
    this.markInitialSelection()
  }

  // After the initial server render, auto-pick the first available slot so a
  // customer can submit with one tap if they're fine with the soonest opening.
  markInitialSelection() {
    const first = this.firstAvailableButton()
    if (first) this.activateButton(first)
  }

  async dateChanged() {
    const date = this.dateTarget.value
    if (!date) return
    this.setHint("loading…")
    try {
      const url = `/locations/${this.locationIdValue}/availability?date=${date}&step=${this.stepValue}`
      const res = await fetch(url, { headers: { "Accept": "application/json" }, credentials: "same-origin" })
      const data = await res.json()
      this.renderSlots(data.slots, data.closed)
    } catch (_e) {
      this.setHint("couldn't load slots — try again")
    }
  }

  selectSlot(event) {
    this.activateButton(event.currentTarget)
  }

  // ----- helpers -----

  activateButton(btn) {
    this.slotsTarget.querySelectorAll("button[data-time]").forEach((b) => {
      b.classList.remove("border-blue-500", "bg-blue-50", "text-blue-900")
      b.classList.add("border-slate-200")
    })
    btn.classList.remove("border-slate-200")
    btn.classList.add("border-blue-500", "bg-blue-50", "text-blue-900")
    this.selectedTarget.value = btn.dataset.time
  }

  firstAvailableButton() {
    return this.slotsTarget.querySelector("button[data-time]:not([disabled])")
  }

  renderSlots(slots, closed) {
    this.selectedTarget.value = ""
    if (closed || !slots || slots.length === 0) {
      this.slotsTarget.innerHTML = this.emptyMessage("Closed on this day.")
      this.setHint("")
      return
    }
    const anyOpen = slots.some((s) => !s.past)
    if (!anyOpen) {
      this.slotsTarget.innerHTML = this.emptyMessage("No more openings — try another date.")
      this.setHint("")
      return
    }
    this.slotsTarget.innerHTML = slots.map((s) => this.slotHtml(s)).join("")
    this.setHint(`${this.stepValue}-minute slots`)
    const first = this.firstAvailableButton()
    if (first) this.activateButton(first)
  }

  slotHtml(s) {
    if (s.past) {
      return `<button type="button" disabled
        class="border border-slate-200 bg-slate-50 text-slate-300 rounded-lg py-2 text-sm cursor-not-allowed">${this.escape(s.label)}</button>`
    }
    const busyBadge = s.full
      ? `<span class="absolute -top-1.5 -right-1.5 text-[9px] uppercase font-semibold bg-amber-500 text-white px-1.5 py-0.5 rounded-full">busy</span>`
      : ""
    return `<button type="button"
      data-action="click->time-picker#selectSlot"
      data-time="${this.escape(s.time)}"
      class="border-2 border-slate-200 hover:border-blue-400 rounded-lg py-2 text-sm relative">
        <span class="font-medium">${this.escape(s.label)}</span>${busyBadge}
      </button>`
  }

  emptyMessage(text) {
    return `<p class="col-span-3 text-sm text-slate-500 text-center py-4">${this.escape(text)}</p>`
  }

  setHint(text) {
    if (this.hasHintTarget) this.hintTarget.textContent = text
  }

  escape(s) {
    const div = document.createElement("div")
    div.textContent = s
    return div.innerHTML
  }
}
