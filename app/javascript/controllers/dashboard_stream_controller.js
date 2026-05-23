import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = { orgId: Number }

  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "DashboardChannel" },
      {
        received: (_data) => {
          // Skip a reload if this tab just did an optimistic drag-and-drop —
          // the card is already in the right column locally.
          if (window.__kanbanOptimistic && Date.now() - window.__kanbanOptimistic < 2500) return
          window.location.reload()
        }
      }
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }
}
