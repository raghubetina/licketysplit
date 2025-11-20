import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.handleStreamRender = this.handleStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.handleStreamRender)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.handleStreamRender)
  }

  handleStreamRender(event) {
    const fallbackToDefaultActions = event.detail.render
    const streamElement = event.target

    event.detail.render = (currentStreamElement) => {
      fallbackToDefaultActions(currentStreamElement)

      // After render, find the target and add animation class
      const targetId = streamElement.getAttribute("target")
      const target = document.getElementById(targetId)

      if (target) {
        // Target the first child element if it's a turbo-frame, since that's the visible content
        const elementToHighlight = target.tagName === 'TURBO-FRAME' && target.firstElementChild
          ? target.firstElementChild
          : target

        elementToHighlight.classList.add("turbo-stream-updated")

        elementToHighlight.addEventListener("animationend", () => {
          elementToHighlight.classList.remove("turbo-stream-updated")
        }, { once: true })
      }
    }
  }
}
