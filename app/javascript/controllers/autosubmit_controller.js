import { Controller } from "@hotwired/stimulus"

// Submits the enclosing form when the controlled element changes. Replaces
// inline onchange="this.form.submit()" handlers, which a strict script-src CSP
// forbids.
export default class extends Controller {
  submit() {
    this.element.form.requestSubmit()
  }
}
