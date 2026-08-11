import { Controller } from '@hotwired/stimulus'

// When the worker running a parse dies, no broadcast ever arrives and the page
// spins forever. Fall back to a local timer so the user is told something is
// wrong even though the server has gone quiet.
//
// elapsedValue is rendered by the server so a reload does not restart the wait,
// and so the deadline does not depend on the client's clock being correct.
export default class extends Controller {
  static targets = ['waiting', 'stalled']
  static values = { after: Number, elapsed: Number }

  connect() {
    const remaining = this.afterValue - this.elapsedValue * 1000
    this.timer = setTimeout(() => this.stall(), Math.max(remaining, 0))
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  stall() {
    this.waitingTarget.hidden = true
    this.stalledTarget.hidden = false
  }
}
