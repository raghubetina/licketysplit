import { Controller } from "@hotwired/stimulus"
import { attach } from "@frsource/autoresize-textarea"

export default class extends Controller {
  connect() {
    const { detach } = attach(this.element)
    this.detach = detach
  }

  disconnect() {
    if (this.detach) {
      this.detach()
    }
  }
}
