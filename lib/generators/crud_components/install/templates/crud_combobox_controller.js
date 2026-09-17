import { Controller } from "@hotwired/stimulus"

// Optional progressive enhancement for a CrudComponents combobox filter (a
// belongs_to with many choices). Without it the input is a plain text filter.
//
// Typing asks the page the filter sits on for suggestions
// (?crud_choices=<field>&crud_term=<text>) — so they come from the same
// controller, ability and parent as the list — and lists them under the input.
// Picking one submits the target's identify_by value through a hidden input;
// typing again goes back to free text over the label.
//
// Keyboard: ArrowDown/ArrowUp move through the list (and open it), Enter picks
// the highlighted suggestion (or submits the free text when none is), Escape
// closes the list, and clears the text when the list is already closed.
export default class extends Controller {
  static targets = ["input", "listbox"]
  static classes = ["option", "active"]
  static values = {
    url: String,
    field: String,
    param: String,
    choicesParam: String,
    termParam: String,
    source: String,
    label: String,
    autosubmit: Boolean,
    delay: { type: Number, default: 200 }
  }

  connect() {
    this.options = []
    this.activeIndex = -1
    this.hidden = document.createElement("input")
    this.hidden.type = "hidden"
    const form = this.inputTarget.getAttribute("form")
    if (form) this.hidden.setAttribute("form", form)
    this.inputTarget.insertAdjacentElement("afterend", this.hidden)

    const input = this.inputTarget
    input.setAttribute("role", "combobox")
    input.setAttribute("aria-autocomplete", "list")
    input.setAttribute("aria-expanded", "false")
    input.setAttribute("aria-controls", this.listboxTarget.id)

    // A value the server recognised as one of the choices shows its label.
    if (this.labelValue && input.value) this.pick(input.value, this.labelValue, false)

    this.onInput = () => this.typed()
    this.onKeydown = (event) => this.keydown(event)
    this.onBlur = () => this.close()
    this.onFocus = () => { if (!this.hidden.name && input.value === "") this.search() }
    input.addEventListener("input", this.onInput)
    input.addEventListener("keydown", this.onKeydown)
    input.addEventListener("blur", this.onBlur)
    input.addEventListener("focus", this.onFocus)
  }

  disconnect() {
    const input = this.inputTarget
    input.removeEventListener("input", this.onInput)
    input.removeEventListener("keydown", this.onKeydown)
    input.removeEventListener("blur", this.onBlur)
    input.removeEventListener("focus", this.onFocus)
    clearTimeout(this.timer)
    this.request?.abort()
    this.hidden.remove()
  }

  // Free text again: the visible input carries the param.
  typed() {
    if (this.hidden.name) {
      this.hidden.removeAttribute("name")
      this.hidden.value = ""
      this.inputTarget.name = this.paramValue
    }
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.search(), this.delayValue)
  }

  async search() {
    this.request?.abort()
    const request = new AbortController()
    this.request = request
    const url = new URL(this.urlValue, window.location.href)
    url.searchParams.set(this.choicesParamValue, this.fieldValue)
    url.searchParams.set(this.termParamValue, this.inputTarget.value)
    try {
      const response = await fetch(url, {
        headers: { Accept: "text/html" },
        credentials: "same-origin",
        signal: request.signal
      })
      if (!response.ok) return this.close()
      this.show(this.parse(await response.text()))
    } catch (error) {
      if (error.name !== "AbortError") this.close()
    }
  }

  // The suggestions out of the page: the fragment for this filter param, from
  // the collection or filter form this combobox belongs to.
  parse(html) {
    const doc = new DOMParser().parseFromString(html, "text/html")
    const param = CSS.escape(this.paramValue)
    const own = `[data-crud-choices="${param}"][data-crud-choices-source="${CSS.escape(this.sourceValue)}"]`
    const list = doc.querySelector(own) || doc.querySelector(`[data-crud-choices="${param}"]`)
    if (!list) return []
    return Array.from(list.querySelectorAll("li")).map((li) => ({ value: li.dataset.value, label: li.textContent.trim() }))
  }

  show(options) {
    this.options = options
    this.activeIndex = -1
    const listbox = this.listboxTarget
    listbox.replaceChildren(...options.map((option, index) => this.optionElement(option, index)))
    if (options.length === 0 || document.activeElement !== this.inputTarget) return this.close()

    listbox.hidden = false
    this.inputTarget.setAttribute("aria-expanded", "true")
  }

  optionElement(option, index) {
    const li = document.createElement("li")
    li.id = `${this.listboxTarget.id}_${index}`
    li.setAttribute("role", "option")
    li.setAttribute("aria-selected", "false")
    li.classList.add(...this.optionClasses)
    li.textContent = option.label
    li.title = option.label
    // mousedown, not click: keep the focus in the input so blur doesn't close first
    li.addEventListener("mousedown", (event) => {
      event.preventDefault()
      this.pick(option.value, option.label, true)
    })
    return li
  }

  keydown(event) {
    const open = !this.listboxTarget.hidden
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        open ? this.move(1) : this.search()
        break
      case "ArrowUp":
        event.preventDefault()
        if (open) this.move(-1)
        break
      case "Enter":
        if (open && this.activeIndex >= 0) {
          event.preventDefault()
          const option = this.options[this.activeIndex]
          this.pick(option.value, option.label, true)
        } else {
          this.close()
        }
        break
      case "Escape":
        if (open) {
          event.preventDefault()
          this.close()
        } else if (this.inputTarget.value !== "") {
          event.preventDefault()
          this.inputTarget.value = ""
          this.typed()
        }
        break
      case "Tab":
        this.close()
        break
    }
  }

  move(step) {
    if (this.options.length === 0) return
    const count = this.options.length
    this.activeIndex = this.activeIndex < 0 && step < 0 ? count - 1 : (this.activeIndex + step + count) % count
    Array.from(this.listboxTarget.children).forEach((li, index) => {
      const active = index === this.activeIndex
      li.setAttribute("aria-selected", String(active))
      this.activeClasses.forEach((name) => li.classList.toggle(name, active))
      if (active) {
        this.inputTarget.setAttribute("aria-activedescendant", li.id)
        li.scrollIntoView({ block: "nearest" })
      }
    })
  }

  // The picked target: its identify_by value goes in the hidden input, the
  // visible one only shows the label.
  pick(value, label, submit) {
    clearTimeout(this.timer)
    this.request?.abort()
    this.hidden.name = this.paramValue
    this.hidden.value = value
    this.inputTarget.removeAttribute("name")
    this.inputTarget.value = label
    this.close()
    if (submit && this.autosubmitValue) this.inputTarget.form?.requestSubmit()
  }

  close() {
    this.listboxTarget.hidden = true
    this.activeIndex = -1
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
  }
}
