import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "submit", "input", "output", "outputWrapper", "loading", "controls", "error"]

  connect() {
    this.streaming = false
    this.abortController = null
    this.accumulatedContent = ""
  }

  disconnect() {
    this.abort()
  }

  submit(event) {
    event.preventDefault()
    if (this.streaming) return

    this.startStream()
  }

  regenerate(event) {
    event.preventDefault()
    if (this.streaming) return

    this.startStream()
  }

  async startStream() {
    this.streaming = true
    this.accumulatedContent = ""

    const formData = new FormData(this.formTarget)
    const url = this.formTarget.action

    this.disableForm()
    this.showLoading()
    this.hideControls()
    this.hideError()

    this.abortController = new AbortController()

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      const headers = { "Accept": "text/event-stream" }
      if (csrfToken) headers["X-CSRF-Token"] = csrfToken

      const response = await fetch(url, {
        method: "POST",
        headers,
        body: formData,
        signal: this.abortController.signal
      })

      if (!response.ok) {
        this.showError("Request failed")
        return
      }

      const reader = response.body.getReader()
      const decoder = new TextDecoder()
      const parser = new SSEParser()

      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        const text = decoder.decode(value, { stream: true })
        parser.parse(text, (event, data) => this.handleSSEEvent(event, data))
      }

      parser.flush((event, data) => this.handleSSEEvent(event, data))
    } catch (error) {
      if (error.name === "AbortError") return
      this.showError(error.message)
    }
  }

  handleSSEEvent(event, data) {
    switch (event) {
      case "token":
        this.appendToken(data.content)
        break
      case "done":
        this.streaming = false
        this.onStreamComplete()
        break
      case "error":
        this.streaming = false
        this.showError(data.error)
        break
    }
  }

  appendToken(content) {
    if (!this.accumulatedContent && this.hasOutputTarget) {
      this.outputTarget.value = ""
    }

    this.accumulatedContent += content
    this.outputTarget.value = this.accumulatedContent

    this.outputTarget.style.height = "auto"
    this.outputTarget.style.height = this.outputTarget.scrollHeight + "px"
  }

  onStreamComplete() {
    this.enableForm()
    this.hideLoading()
    this.showControls()

    this.outputTarget.style.height = "auto"
    this.outputTarget.style.height = this.outputTarget.scrollHeight + "px"
  }

  showLoading() {
    this.outputWrapperTarget.classList.add("hidden")
    this.loadingTarget.classList.remove("hidden")
  }

  hideLoading() {
    this.loadingTarget.classList.add("hidden")
    this.outputWrapperTarget.classList.remove("hidden")
  }

  showControls() {
    if (this.hasControlsTarget) {
      this.controlsTarget.classList.remove("hidden")
    }
  }

  hideControls() {
    if (this.hasControlsTarget) {
      this.controlsTarget.classList.add("hidden")
    }
  }

  showError(message) {
    this.streaming = false
    this.enableForm()
    this.hideLoading()

    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove("hidden")
    }

    this.outputTarget.value = ""
    this.accumulatedContent = ""
  }

  hideError() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.add("hidden")
    }
  }

  disableForm() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
      this.submitTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
    if (this.hasInputTarget) {
      this.inputTarget.disabled = true
    }
  }

  enableForm() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
      this.submitTarget.classList.remove("opacity-50", "cursor-not-allowed")
    }
    if (this.hasInputTarget) {
      this.inputTarget.disabled = false
      this.inputTarget.focus()
    }
  }

  copy(event) {
    event.preventDefault()

    const text = this.outputTarget.value || ""
    if (!text) return

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(() => this.showCopied(event.currentTarget))
    } else {
      this.fallbackCopy(text, event.currentTarget)
    }
  }

  abort() {
    if (this.abortController) {
      this.abortController.abort()
      this.abortController = null
    }
    this.streaming = false
    this.enableForm()
    this.hideLoading()
    this.accumulatedContent = ""
  }

  showCopied(button) {
    const original = button.innerHTML
    button.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-emerald-500">
        <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
      </svg>
    `
    setTimeout(() => {
      button.innerHTML = original
    }, 2000)
  }

  fallbackCopy(text, button) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.opacity = "0"
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand("copy")
    document.body.removeChild(textarea)
    this.showCopied(button)
  }
}

class SSEParser {
  constructor() {
    this.buffer = ""
    this.currentEvent = "message"
  }

  parse(chunk, callback) {
    this.buffer += chunk
    const parts = this.buffer.split("\n\n")
    this.buffer = parts.pop() || ""

    for (const part of parts) {
      this.parseEventBlock(part, callback)
    }
  }

  flush(callback) {
    if (this.buffer.trim()) {
      this.parseEventBlock(this.buffer, callback)
      this.buffer = ""
    }
  }

  parseEventBlock(block, callback) {
    let event = "message"
    let data = ""

    for (const line of block.split("\n")) {
      if (line.startsWith("event: ")) {
        event = line.slice(7).trim()
      } else if (line.startsWith("data: ")) {
        data = line.slice(6)
      }
    }

    if (data) {
      try {
        const parsed = JSON.parse(data)
        callback(event, parsed)
      } catch {
        // Skip malformed data
      }
    }
  }
}
