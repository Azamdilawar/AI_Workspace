import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { value: String }

  connect() {
    this.originalHtml = this.element.innerHTML
  }

  copy(event) {
    event.preventDefault()
    event.stopPropagation()

    const text = this.valueValue || this.element.dataset.copyValue || ""

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(() => this.showCopied())
    } else {
      this.fallbackCopy(text)
    }
  }

  fallbackCopy(text) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand("copy")
    document.body.removeChild(textarea)
    this.showCopied()
  }

  showCopied() {
    this.element.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-3.5 h-3.5 text-emerald-500">
        <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
      </svg>
    `

    setTimeout(() => {
      this.element.innerHTML = this.originalHtml
    }, 2000)
  }
}