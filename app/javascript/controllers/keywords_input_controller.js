import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "chipContainer"]

  connect() {
    // Read existing hidden inputs (pre-rendered by ERB on page load)
    this._keywords = Array.from(
      this.element.querySelectorAll("input[type=hidden]")
    ).map(i => i.value)
    this.renderChips()
  }

  addChip(event) {
    if (event.key === "Enter" || event.key === ",") {
      event.preventDefault()
      const value = this.inputTarget.value.trim()
      if (value) {
        this._keywords.push(value)
        this.inputTarget.value = ""
        this.renderChips()
      }
    } else if (event.key === "Backspace" && this.inputTarget.value === "") {
      this._keywords.pop()
      this.renderChips()
    }
  }

  removeChip(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    this._keywords.splice(index, 1)
    this.renderChips()
  }

  renderChips() {
    const container = this.chipContainerTarget
    const input = this.inputTarget

    // Remove all children except the live text input
    Array.from(container.children).forEach(child => {
      if (child !== input) {
        container.removeChild(child)
      }
    })

    // Prepend hidden inputs and chip spans before the text input
    this._keywords.forEach((kw, i) => {
      // Hidden input for Rails form param
      const hidden = document.createElement("input")
      hidden.type = "hidden"
      hidden.name = "blog[keywords][]"
      hidden.value = kw
      container.insertBefore(hidden, input)

      // Chip span
      const chip = document.createElement("span")
      chip.className = "inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-semibold bg-pink-50 text-pink-700 border border-pink-200"

      // Keyword text — using textContent (never innerHTML) to prevent XSS
      const labelSpan = document.createElement("span")
      labelSpan.textContent = kw
      chip.appendChild(labelSpan)

      // Remove button
      const btn = document.createElement("button")
      btn.type = "button"
      btn.dataset.action = "click->keywords-input#removeChip"
      btn.dataset.index = String(i)
      btn.setAttribute("aria-label", "Remove " + kw)
      btn.className = "h-4 w-4 inline-flex items-center justify-center rounded-full hover:bg-pink-200"
      btn.textContent = "×"

      chip.appendChild(btn)
      container.insertBefore(chip, input)
    })
  }
}
