import { Controller } from "@hotwired/stimulus"

// Optional progressive enhancement for a CrudComponents value filter (a
// belongs_to). Without it the filter is a plain <select multiple>.
//
// Hides the select behind a button ("All", the single value, or "3 of 12")
// that opens a popover: a search box over the options the select already
// carries, "Select all (N)" / "Select none", the values as checkboxes, and
// Apply / Cancel. Apply writes the selection back into the select and, in the
// inline filter row, submits the form. Ticking every value means no filter.
//
// Keyboard: the button opens the popover and focuses the search. ArrowDown and
// ArrowUp move between the checkboxes, Space toggles one, Enter applies and
// Escape cancels. A click outside cancels too.
export default class extends Controller {
  static targets = ["select"]
  static values = { label: String, autosubmit: Boolean, texts: Object }

  connect() {
    this.select = this.selectTarget
    this.select.hidden = true
    this.uid = `crud-value-filter-${Math.random().toString(36).slice(2, 10)}`

    this.button = this.buildButton("btn btn-sm btn-outline-secondary text-truncate mw-100", "", () =>
      (this.isOpen ? this.close() : this.open())
    )
    this.button.setAttribute("aria-haspopup", "dialog")
    this.button.setAttribute("aria-expanded", "false")
    this.button.setAttribute("aria-controls", this.uid)
    this.element.append(this.button)
    this.renderButton()

    this.onOutside = (event) => {
      if (this.isOpen && !this.element.contains(event.target)) this.close(false)
    }
    this.onMove = () => this.place()
    document.addEventListener("mousedown", this.onOutside)
  }

  disconnect() {
    document.removeEventListener("mousedown", this.onOutside)
    this.stopFollowing()
    this.button.remove()
    this.popover?.remove()
    this.select.hidden = false
  }

  get isOpen() {
    return this.popover && !this.popover.hidden
  }

  get options() {
    return Array.from(this.select.options).map((option) => ({ value: option.value, label: option.text }))
  }

  renderButton() {
    const picked = Array.from(this.select.selectedOptions)
    const texts = this.textsValue
    let text = texts.all
    if (picked.length === 1) text = picked[0].text
    else if (picked.length > 1) text = this.format(texts.some, picked.length, this.select.options.length)
    this.button.textContent = text
    this.button.title = text
    this.button.setAttribute("aria-label", `${this.labelValue}: ${text}`)
  }

  // ── popover ───────────────────────────────────────────────────────────
  open() {
    this.chosen = new Set(Array.from(this.select.selectedOptions).map((option) => option.value))
    this.build()
    this.search.value = ""
    this.show(this.options)
    this.popover.hidden = false
    this.place()
    window.addEventListener("scroll", this.onMove, true)
    window.addEventListener("resize", this.onMove)
    this.button.setAttribute("aria-expanded", "true")
    this.search.focus()
  }

  close(focusButton = true) {
    this.stopFollowing()
    if (this.popover) this.popover.hidden = true
    this.button.setAttribute("aria-expanded", "false")
    if (focusButton) this.button.focus()
  }

  stopFollowing() {
    window.removeEventListener("scroll", this.onMove, true)
    window.removeEventListener("resize", this.onMove)
  }

  // Fixed to the viewport, under the button, so a scrolling table wrapper does
  // not clip it.
  place() {
    const anchor = this.button.getBoundingClientRect()
    const room = document.documentElement.clientWidth - this.popover.offsetWidth - 8
    this.popover.style.position = "fixed"
    this.popover.style.top = `${anchor.bottom + 2}px`
    this.popover.style.left = `${Math.max(0, Math.min(anchor.left, room))}px`
    this.list.style.maxHeight = `${Math.max(96, Math.min(256, window.innerHeight - anchor.bottom - 150))}px`
  }

  apply() {
    if (this.chosen.size === this.select.options.length) this.chosen.clear()
    for (const option of this.select.options) option.selected = this.chosen.has(option.value)
    this.close()
    this.renderButton()
    if (this.autosubmitValue) this.select.form?.requestSubmit()
  }

  build() {
    if (this.popover) return

    const texts = this.textsValue
    this.popover = this.node("div", "dropdown-menu show p-2 shadow", {
      id: this.uid, role: "dialog", "aria-label": this.labelValue
    })
    this.popover.style.minWidth = "18rem"
    this.popover.style.maxWidth = "24rem"
    this.popover.hidden = true

    this.search = this.node("input", "form-control form-control-sm mb-2", {
      type: "search", placeholder: texts.search, "aria-label": texts.search, autocomplete: "off"
    })
    this.search.addEventListener("input", () => this.show(this.matching()))

    const links = this.node("div", "d-flex flex-wrap align-items-center column-gap-2 small mb-1")
    this.allButton = this.link(texts.select_all, () => this.setShown(true))
    this.count = this.node("span", "ms-auto text-muted text-nowrap", { "aria-live": "polite" })
    links.append(this.allButton, this.link(texts.select_none, () => this.setShown(false)), this.count)

    this.list = this.node("div", "overflow-auto border-top border-bottom py-1 mb-2", {
      role: "group", "aria-label": this.labelValue
    })

    const actions = this.node("div", "d-flex justify-content-end gap-2")
    actions.append(this.buildButton("btn btn-sm btn-outline-secondary", texts.cancel, () => this.close()),
                   this.buildButton("btn btn-sm btn-primary", texts.apply, () => this.apply()))

    this.popover.append(this.search, links, this.list, actions)
    this.popover.addEventListener("keydown", (event) => this.keydown(event))
    this.element.append(this.popover)
  }

  // ── list ──────────────────────────────────────────────────────────────
  matching() {
    const needle = this.search.value.trim().toLowerCase()
    return this.options.filter((option) => option.label.toLowerCase().includes(needle))
  }

  show(options) {
    this.shown = options
    this.list.replaceChildren(...options.map((option, index) => this.item(option, index)))
    this.count.textContent = this.format(this.textsValue.shown, options.length)
    this.allButton.textContent = this.format(this.textsValue.select_all, options.length)
  }

  item(option, index) {
    const wrapper = this.node("div", "form-check text-truncate")
    const id = `${this.uid}-${index}`
    const checkbox = this.node("input", "form-check-input", { type: "checkbox", id })
    checkbox.value = option.value
    checkbox.checked = this.chosen.has(option.value)
    checkbox.addEventListener("change", () => {
      if (checkbox.checked) this.chosen.add(option.value)
      else this.chosen.delete(option.value)
    })
    const label = this.node("label", "form-check-label", { for: id, title: option.label })
    label.textContent = option.label
    wrapper.append(checkbox, label)
    return wrapper
  }

  setShown(checked) {
    for (const option of this.shown) {
      if (checked) this.chosen.add(option.value)
      else this.chosen.delete(option.value)
    }
    for (const checkbox of this.checkboxes) checkbox.checked = checked
  }

  get checkboxes() {
    return Array.from(this.list.querySelectorAll("input[type=checkbox]"))
  }

  // ── keyboard ──────────────────────────────────────────────────────────
  keydown(event) {
    switch (event.key) {
      case "Escape":
        event.preventDefault()
        event.stopPropagation()
        this.close()
        break
      case "Enter":
        if (event.target.tagName === "BUTTON") return
        event.preventDefault()
        this.apply()
        break
      case "ArrowDown":
      case "ArrowUp": {
        const boxes = this.checkboxes
        if (boxes.length === 0) return
        event.preventDefault()
        const index = boxes.indexOf(document.activeElement)
        const next = index < 0 ? 0 : index + (event.key === "ArrowDown" ? 1 : -1)
        if (next < 0) this.search.focus()
        else boxes[Math.min(next, boxes.length - 1)].focus()
        break
      }
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────
  node(tag, className, attributes = {}) {
    const element = document.createElement(tag)
    element.className = className
    for (const [name, value] of Object.entries(attributes)) element.setAttribute(name, value)
    return element
  }

  buildButton(className, text, onClick) {
    const button = this.node("button", className, { type: "button" })
    button.textContent = text
    button.addEventListener("click", onClick)
    return button
  }

  link(text, onClick) {
    return this.buildButton("btn btn-link btn-sm p-0 text-nowrap", text, onClick)
  }

  format(text, count, total) {
    return text.replace("{count}", count.toLocaleString()).replace("{total}", total?.toLocaleString())
  }
}
