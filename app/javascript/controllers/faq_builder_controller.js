import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "rowContainer"]

  addRow(event) {
    event.preventDefault()
    const fragment = this.templateTarget.content.cloneNode(true)
    this.rowContainerTarget.appendChild(fragment)
    this.rowContainerTarget.lastElementChild?.querySelector('input[type=text]')?.focus()
  }

  removeRow(event) {
    event.preventDefault()
    event.currentTarget.closest('[data-faq-row]')?.remove()
  }
}
