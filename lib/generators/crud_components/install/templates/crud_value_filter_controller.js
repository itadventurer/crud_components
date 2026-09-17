import { Controller } from "@hotwired/stimulus"

// Optional progressive enhancement for a CrudComponents value filter (a
// belongs_to). Without it the filter is a plain <select multiple>.
//
// Hides the select behind a button ("All", the single value, or "3 of 12")
// that opens a popover: a search box, "Select all (N)" / "Select none", the
// values as checkboxes, and Apply / Cancel. Apply writes the selection back
// into the select and, in the inline filter row, submits the form. Selecting
// every value means no filter.
//
// The page lists a limited number of values. When there are more, the search
// asks the page it sits on for matches (?crud_choices=<field>&crud_term=<text>),
// so they come from the same controller, ability and parent as the list.
//
// Keyboard: the button opens the popover and focuses the search. ArrowDown and
// ArrowUp move between the checkboxes, Space toggles one, Enter applies and
// Escape cancels. A click outside cancels too.
export default class extends Controller {
  static targets = ["select"]
  static values = {
    url: String,
    field: String,
    param: String,
    choicesParam: String,
    termParam: String,
    source: String,
    label: String,
    nullValue: String,
    total: Number,
    remote: Boolean,
    autosubmit: Boolean,
    texts: Object,
    css: Object,
    delay: { type: Number, default: 250 }
  }

  connect() {
    this.select = this.selectTarget
    this.select.hidden = true
    this.uid = `crud-value-filter-${Math.random().toString(36).slice(2, 10)}`

    this.button = this.node("button", this.cssValue.button, {
      type: "button",
      "aria-haspopup": "dialog",
      "aria-expanded": "false",
      "aria-controls": this.uid
    })
    this.button.addEventListener("click", () => (this.isOpen ? this.cancel() : this.open()))
    this.element.append(this.button)
    this.renderButton()

    this.onOutside = (event) => {
      if (this.isOpen && !this.element.contains(event.target)) this.cancel(false)
    }
    document.addEventListener("mousedown", this.onOutside)
    this.onMove = () => this.place()
  }

  disconnect() {
    document.removeEventListener("mousedown", this.onOutside)
    window.removeEventListener("scroll", this.onMove, true)
    window.removeEventListener("resize", this.onMove)
    clearTimeout(this.timer)
    this.request?.abort()
    this.button.remove()
    this.popover?.remove()
    this.select.hidden = false
  }

  get isOpen() {
    return this.popover && !this.popover.hidden
  }

  // ── button ────────────────────────────────────────────────────────────
  renderButton() {
    const picked = Array.from(this.select.selectedOptions)
    let text
    if (picked.length === 0) text = this.textsValue.all
    else if (picked.length === 1) text = picked[0].text
    else text = this.format(this.textsValue.some, { count: picked.length, total: this.totalValue })
    this.button.textContent = text
    this.button.title = text
    this.button.setAttribute("aria-label", `${this.labelValue}: ${text}`)
  }

  // ── popover ───────────────────────────────────────────────────────────
  open() {
    this.inline = Array.from(this.select.options).map((option) => ({ value: option.value, label: option.text }))
    this.chosen = new Map(Array.from(this.select.selectedOptions).map((option) => [option.value, option.text]))
    this.build()
    this.search.value = ""
    this.show(this.inline, this.remoteValue ? this.totalValue : null)
    this.popover.hidden = false
    this.place()
    window.addEventListener("scroll", this.onMove, true)
    window.addEventListener("resize", this.onMove)
    this.button.setAttribute("aria-expanded", "true")
    this.search.focus()
  }

  // Fixed to the viewport, under the button, so a scrolling table wrapper
  // does not clip it.
  place() {
    const anchor = this.button.getBoundingClientRect()
    const style = this.popover.style
    const width = document.documentElement.clientWidth
    const height = window.innerHeight
    style.position = "fixed"
    style.top = `${anchor.bottom + 2}px`
    style.left = `${Math.max(0, Math.min(anchor.left, width - this.popover.offsetWidth - 8))}px`
    this.list.style.maxHeight = `${Math.max(96, Math.min(256, height - anchor.bottom - 150))}px`
  }

  close(focusButton = true) {
    window.removeEventListener("scroll", this.onMove, true)
    window.removeEventListener("resize", this.onMove)
    clearTimeout(this.timer)
    this.request?.abort()
    if (this.popover) this.popover.hidden = true
    this.button.setAttribute("aria-expanded", "false")
    if (focusButton) this.button.focus()
  }

  cancel(focusButton = true) {
    this.close(focusButton)
  }

  apply() {
    const everything = !this.remoteValue && this.inline.every((option) => this.chosen.has(option.value))
    if (everything) this.chosen.clear()

    const present = new Set(Array.from(this.select.options).map((option) => option.value))
    for (const [value, label] of this.chosen) {
      if (!present.has(value)) this.select.add(new Option(label, value))
    }
    for (const option of this.select.options) option.selected = this.chosen.has(option.value)

    this.close()
    this.renderButton()
    this.select.dispatchEvent(new Event("change", { bubbles: true }))
    if (this.autosubmitValue) this.select.form?.requestSubmit()
  }

  build() {
    if (this.popover) return

    const css = this.cssValue
    const texts = this.textsValue
    this.popover = this.node("div", css.menu, { id: this.uid, role: "dialog", "aria-label": this.labelValue })
    this.popover.style.minWidth = "18rem"
    this.popover.style.maxWidth = "24rem"
    this.popover.hidden = true

    this.search = this.node("input", css.search, {
      type: "search", placeholder: texts.search, "aria-label": texts.search, autocomplete: "off"
    })
    this.search.addEventListener("input", () => this.searched())

    const links = this.node("div", css.links)
    this.allButton = this.node("button", css.link, { type: "button" })
    this.allButton.addEventListener("click", () => this.setShown(true))
    const noneButton = this.node("button", css.link, { type: "button" })
    noneButton.textContent = texts.select_none
    noneButton.addEventListener("click", () => this.setShown(false))
    this.count = this.node("span", css.count, { "aria-live": "polite" })
    links.append(this.allButton, noneButton, this.count)

    this.list = this.node("div", css.list, { role: "group", "aria-label": this.labelValue })

    const actions = this.node("div", css.actions)
    const cancel = this.node("button", css.cancel, { type: "button" })
    cancel.textContent = texts.cancel
    cancel.addEventListener("click", () => this.cancel())
    const apply = this.node("button", css.apply, { type: "button" })
    apply.textContent = texts.apply
    apply.addEventListener("click", () => this.apply())
    actions.append(cancel, apply)

    this.popover.append(this.search, links, this.list, actions)
    this.popover.addEventListener("keydown", (event) => this.keydown(event))
    this.element.append(this.popover)
  }

  // ── list ──────────────────────────────────────────────────────────────
  searched() {
    const term = this.search.value.trim()
    clearTimeout(this.timer)
    if (!this.remoteValue) return this.show(this.matchingInline(term), null)
    if (term === "") return this.show(this.inline, this.totalValue)
    this.timer = setTimeout(() => this.fetchMatches(term), this.delayValue)
  }

  matchingInline(term) {
    const needle = term.toLowerCase()
    return this.inline.filter((option) => option.label.toLowerCase().includes(needle))
  }

  async fetchMatches(term) {
    this.request?.abort()
    const request = new AbortController()
    this.request = request
    const url = new URL(this.urlValue, window.location.href)
    url.searchParams.set(this.choicesParamValue, this.fieldValue)
    url.searchParams.set(this.termParamValue, term)
    try {
      const response = await fetch(url, {
        headers: { Accept: "text/html" },
        credentials: "same-origin",
        signal: request.signal
      })
      if (!response.ok) return
      const { options, total } = this.parse(await response.text())
      const blank = this.matchingInline(term).filter((option) => option.value === this.nullValue)
      this.show(blank.concat(options), total + blank.length)
    } catch (error) {
      if (error.name !== "AbortError") throw error
    }
  }

  // The matches out of the page: the fragment for this filter param, from the
  // collection or filter form this control belongs to.
  parse(html) {
    const doc = new DOMParser().parseFromString(html, "text/html")
    const param = CSS.escape(this.paramValue)
    const own = `[data-crud-choices="${param}"][data-crud-choices-source="${CSS.escape(this.sourceValue)}"]`
    const list = doc.querySelector(own) || doc.querySelector(`[data-crud-choices="${param}"]`)
    if (!list) return { options: [], total: 0 }
    const options = Array.from(list.querySelectorAll("li"))
      .map((li) => ({ value: li.dataset.value, label: li.textContent.trim() }))
    return { options, total: Number(list.dataset.crudChoicesTotal) || options.length }
  }

  // Renders `options`, with chosen values that are not among them on top so a
  // selection never disappears. `total` is how many match in all (null: all
  // are listed).
  show(options, total) {
    const term = this.search.value.trim().toLowerCase()
    const listed = new Set(options.map((option) => option.value))
    const extra = Array.from(this.chosen, ([value, label]) => ({ value, label }))
      .filter((option) => !listed.has(option.value) && option.label.toLowerCase().includes(term))
    this.shown = extra.concat(options)
    this.list.replaceChildren(...this.shown.map((option, index) => this.item(option, index)))

    const texts = this.textsValue
    const count = this.shown.length
    const all = total === null ? count : Math.max(total + extra.length, count)
    this.count.textContent = all > count
      ? this.format(texts.shown_of, { count, total: all })
      : this.format(texts.shown, { count })
    this.allButton.textContent = this.format(texts.select_all, { count })
  }

  item(option, index) {
    const css = this.cssValue
    const wrapper = this.node("div", css.option)
    const id = `${this.uid}-${index}`
    const checkbox = this.node("input", css.checkbox, { type: "checkbox", id })
    checkbox.value = option.value
    checkbox.checked = this.chosen.has(option.value)
    checkbox.addEventListener("change", () => {
      if (checkbox.checked) this.chosen.set(option.value, option.label)
      else this.chosen.delete(option.value)
    })
    const label = this.node("label", css.label, { for: id, title: option.label })
    label.textContent = option.label
    wrapper.append(checkbox, label)
    return wrapper
  }

  setShown(checked) {
    for (const option of this.shown) {
      if (checked) this.chosen.set(option.value, option.label)
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
        this.cancel()
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
        const step = event.key === "ArrowDown" ? 1 : -1
        let next
        if (index < 0) next = step > 0 ? 0 : boxes.length - 1
        else next = index + step
        if (next < 0) return this.search.focus()
        boxes[Math.min(next, boxes.length - 1)].focus()
        break
      }
    }
  }

  // ── helpers ───────────────────────────────────────────────────────────
  node(tag, className, attributes = {}) {
    const element = document.createElement(tag)
    if (className) element.className = className
    for (const [name, value] of Object.entries(attributes)) element.setAttribute(name, value)
    return element
  }

  format(text, values) {
    return text.replace(/\{(\w+)\}/g, (match, key) => (key in values ? values[key].toLocaleString() : match))
  }
}
