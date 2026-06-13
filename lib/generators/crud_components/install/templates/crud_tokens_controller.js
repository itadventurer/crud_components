import { Controller } from "@hotwired/stimulus"

// Optional progressive enhancement for habtm/has_many form fields: replaces a
// `<select multiple>` with a chips-list (each removable with ×) + an "add"
// dropdown. The select stays in the DOM as the hidden source of truth, so the
// form submits identically with or without JavaScript.
//
// Good for sets up to a few hundred (all options live client-side). For very
// large sets, render an autocomplete against your own endpoint instead — see
// the docs (Forms / Extending).
export default class extends Controller {
  connect() {
    this.select = this.element.matches("select[multiple]")
      ? this.element
      : this.element.querySelector("select[multiple]")
    if (!this.select) return

    this.select.style.display = "none"
    this.chips = document.createElement("div")
    this.chips.className = "d-flex flex-wrap gap-1 mb-1"
    this.adder = document.createElement("select")
    this.adder.className = "form-select"
    this.adder.addEventListener("change", () => this.toggle(this.adder.value, true))
    this.select.insertAdjacentElement("beforebegin", this.chips)
    this.select.insertAdjacentElement("beforebegin", this.adder)
    this.render()
  }

  get options() {
    return Array.from(this.select.options)
  }

  render() {
    this.chips.replaceChildren(
      ...this.options.filter((o) => o.selected).map((o) => this.chip(o))
    )
    this.adder.replaceChildren(this.option("", "+ add…"))
    this.options
      .filter((o) => !o.selected)
      .forEach((o) => this.adder.appendChild(this.option(o.value, o.text)))
  }

  chip(option) {
    const chip = document.createElement("span")
    chip.className = "badge text-bg-primary d-inline-flex align-items-center gap-1"
    chip.textContent = option.text
    const close = document.createElement("button")
    close.type = "button"
    close.className = "btn-close btn-close-white"
    close.style.fontSize = ".6rem"
    close.addEventListener("click", () => this.toggle(option.value, false))
    chip.appendChild(close)
    return chip
  }

  option(value, text) {
    const opt = document.createElement("option")
    opt.value = value
    opt.text = text
    return opt
  }

  toggle(value, selected) {
    const option = this.options.find((o) => o.value === value)
    if (!option) return
    option.selected = selected
    this.render()
  }
}
