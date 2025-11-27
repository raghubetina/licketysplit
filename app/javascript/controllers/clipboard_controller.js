import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    text: String
  }

  copy() {
    navigator.clipboard.writeText(this.textValue).then(() => {
      const originalText = this.element.innerHTML
      this.element.innerHTML = '<i class="bi bi-check"></i> Copied!'
      setTimeout(() => {
        this.element.innerHTML = originalText
      }, 2000)
    })
  }
}
