import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String
  }

  toggle(event) {
    const checkbox = event.target
    const participantId = checkbox.value

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ participant_id: participantId })
    }).catch(error => {
      console.error("Toggle failed:", error)
      checkbox.checked = !checkbox.checked
    })
  }
}
