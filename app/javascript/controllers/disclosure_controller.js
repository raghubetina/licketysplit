import { Controller } from '@hotwired/stimulus'

// Collapses an "add a thing" form behind a trigger button so the list of
// existing rows isn't buried under four permanently-open forms.
//
// The server decides the starting state: a form re-rendered with validation
// errors arrives already expanded, so the errors are never hidden behind a
// button the user would have to find and press again.
export default class extends Controller {
  static targets = ['trigger', 'panel', 'field']

  open() {
    this.triggerTarget.hidden = true
    this.triggerTarget.setAttribute('aria-expanded', 'true')
    this.panelTarget.hidden = false

    if (this.hasFieldTarget) this.fieldTarget.focus()
  }

  close() {
    this.panelTarget.hidden = true
    this.triggerTarget.hidden = false
    this.triggerTarget.setAttribute('aria-expanded', 'false')
    this.triggerTarget.focus()
  }

  // Escape closes, matching how every other dismissible thing on the web
  // behaves. Ignored while the panel is already closed so it doesn't steal
  // the key from anything further up.
  closeOnEscape(event) {
    if (event.key === 'Escape' && !this.panelTarget.hidden) {
      event.stopPropagation()
      this.close()
    }
  }
}
