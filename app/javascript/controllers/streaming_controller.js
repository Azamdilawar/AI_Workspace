import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"

export default class extends Controller {
  static targets = ["messages", "submit", "indicator", "input"]
  static values = {
    conversationId: Number,
    regenerateUrl: String
  }

  connect() {
    this.streaming = false
    this.abortController = null
    this.accumulatedContent = ""
    this.assistantElement = null
    this.csv = null
  }

  disconnect() {
    this.abort()
  }

  submit(event) {
    event.preventDefault()
    if (this.streaming) return

    const form = event.target
    const formData = new FormData(form)
    const content = formData.get("message[content]")
    if (!content || !content.trim()) return

    const url = form.action
    this.startStream(url, formData)
  }

  regenerate(event) {
    event.preventDefault()
    if (this.streaming) return

    const url = this.regenerateUrlValue
    const formData = new FormData()
    this.startStream(url, formData)
  }

  async startStream(url, formData) {
    this.streaming = true
    this.accumulatedContent = ""
    this.assistantElement = null

    this.disableForm()
    this.showTypingIndicator()
    this.scrollToBottom()

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
        this.handleStreamError("Request failed")
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

      if (!this.streaming) return

      this.enableForm()
      this.finalizeResponse()
    } catch (error) {
      if (error.name === "AbortError") return
      this.handleStreamError(error.message)
    }
  }

  handleSSEEvent(event, data) {
    switch (event) {
      case "token":
        this.appendToken(data.content)
        break
      case "done":
        this.streaming = false
        this.onStreamComplete(data)
        break
      case "error":
        this.streaming = false
        this.handleStreamError(data.error)
        break
    }
  }

  appendToken(content) {
    this.accumulatedContent += content

    if (!this.assistantElement) {
      this.createAssistantBubble()
    }

    const textEl = this.assistantElement.querySelector(".streaming-text")
    if (textEl) {
      textEl.textContent = this.accumulatedContent
    }

    this.scrollToBottom()
  }

  createAssistantBubble() {
    this.removeTypingIndicator()

    const wrapper = document.createElement("div")
    wrapper.className = "flex justify-start mb-4"
    wrapper.id = "streaming-message"

    wrapper.innerHTML = `
      <div class="max-w-[75%] bg-white border border-slate-200 text-slate-800 rounded-2xl rounded-bl-md px-4 py-3 shadow-sm">
        <div class="text-sm leading-relaxed whitespace-pre-wrap streaming-text"></div>
        <div class="mt-1 text-slate-400 text-[10px] font-medium">
          <span class="streaming-cursor">|</span>
        </div>
      </div>
    `

    if (this.hasMessagesTarget) {
      this.messagesTarget.appendChild(wrapper)
    } else {
      this.element.querySelector('[data-streaming-target="messages"]')?.appendChild(wrapper)
    }

    this.assistantElement = wrapper
  }

  onStreamComplete(data) {
    this.enableForm()
    this.removeTypingIndicator()

    if (this.assistantElement) {
      const textEl = this.assistantElement.querySelector(".streaming-text")
      if (textEl) {
        textEl.innerHTML = this.renderMarkdown(this.accumulatedContent)
      }

      const metaEl = this.assistantElement.querySelector(".streaming-cursor")
      if (metaEl) {
        const count = data.token_count
        metaEl.outerHTML = `
          <span class="message-meta">
            ${count ? `&middot; ${count} tokens` : ""}
          </span>
          <span class="ml-2 inline-flex items-center gap-1">
            <button data-action="click->streaming#regenerate" class="text-slate-400 hover:text-indigo-600 transition-colors" title="Regenerate">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-3.5 h-3.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182" />
              </svg>
            </button>
            <button data-controller="copy" data-action="click->copy#copy" data-copy-value="${this.escapeHtml(this.accumulatedContent)}" class="text-slate-400 hover:text-indigo-600 transition-colors" title="Copy">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-3.5 h-3.5">
                <path stroke-linecap="round" stroke-linejoin="round" d="M15.666 3.888A2.25 2.25 0 0013.5 2.25h-3c-1.03 0-1.9.693-2.166 1.638m7.332 0c.055.194.084.4.084.612v0a.75.75 0 01-.75.75H9a.75.75 0 01-.75-.75v0c0-.212.03-.418.084-.612m7.332 0c.646.049 1.288.11 1.927.184 1.1.128 1.907 1.077 1.907 2.185V19.5a2.25 2.25 0 01-2.25 2.25H6.75A2.25 2.25 0 014.5 19.5V6.257c0-1.108.806-2.057 1.907-2.185a48.208 48.208 0 011.927-.184" />
              </svg>
            </button>
          </span>
        `
      }

      this.assistantElement.id = ""
    }

    this.accumulatedContent = ""
    this.assistantElement = null
  }

  finalizeResponse() {
    this.assistantElement = null
  }

  showTypingIndicator() {
    this.removeTypingIndicator()

    const wrapper = document.createElement("div")
    wrapper.className = "flex justify-start mb-4"
    wrapper.id = "streaming-indicator"
    wrapper.innerHTML = `
      <div class="max-w-[75%] bg-white border border-slate-200 text-slate-800 rounded-2xl rounded-bl-md px-4 py-3 shadow-sm">
        <div class="flex items-center gap-2">
          <span class="w-2 h-2 bg-slate-400 rounded-full animate-bounce" style="animation-delay: 0ms"></span>
          <span class="w-2 h-2 bg-slate-400 rounded-full animate-bounce" style="animation-delay: 150ms"></span>
          <span class="w-2 h-2 bg-slate-400 rounded-full animate-bounce" style="animation-delay: 300ms"></span>
          <span class="text-sm text-slate-400 ml-1">Assistant is thinking...</span>
        </div>
      </div>
    `

    if (this.hasMessagesTarget) {
      this.messagesTarget.appendChild(wrapper)
    } else {
      this.element.querySelector('[data-streaming-target="messages"]')?.appendChild(wrapper)
    }
  }

  removeTypingIndicator() {
    const el = document.getElementById("streaming-indicator")
    if (el) el.remove()
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

  scrollToBottom() {
    if (this.hasMessagesTarget) {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    }
  }

  handleStreamError(message) {
    this.streaming = false
    this.enableForm()
    this.removeTypingIndicator()

    if (this.assistantElement) {
      const metaEl = this.assistantElement.querySelector(".streaming-cursor")
      if (metaEl) {
        metaEl.outerHTML = `<span class="text-red-500 text-xs">Error: ${this.escapeHtml(message)}</span>`
      }
      this.assistantElement.id = ""
    }

    this.accumulatedContent = ""
    this.assistantElement = null
  }

  abort() {
    if (this.abortController) {
      this.abortController.abort()
      this.abortController = null
    }
    this.streaming = false
    this.enableForm()
    this.removeTypingIndicator()
    this.accumulatedContent = ""
    this.assistantElement = null
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  renderMarkdown(text) {
    marked.setOptions({
      breaks: true,
      gfm: true
    })
    return marked.parse(text)
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