import { Controller } from '@hotwired/stimulus'

// Optimistic +/- stepper for uneven shares. Bumps the count immediately,
// POSTs in the background, and lets the broadcast-driven morph reconcile
// the amounts and status text (reverting the count if the POST fails).
export default class extends Controller {
  static targets = ['count']

  adjust(event) {
    const { url, delta } = event.params
    const next = parseInt(this.countTarget.textContent, 10) + delta
    if (next < 0) return

    this.countTarget.textContent = next

    fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')
          .content,
      },
    })
      .then((response) => {
        // fetch only rejects on network failures; HTTP errors resolve
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
      })
      .catch((error) => {
        console.error('Share adjust failed:', error)
        this.countTarget.textContent = next - delta
      })
  }
}
