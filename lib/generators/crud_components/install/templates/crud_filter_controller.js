import { Controller } from "@hotwired/stimulus"

// Optional progressive enhancement for CrudComponents filter forms:
// - strips empty inputs on submit (clean, shareable URLs)
// - auto-submits selects in the inline filter row (wired via data-action)
// Everything works without this controller — plain GET forms.
export default class extends Controller {
  static targets = ["form"]

  clean() {
    this.cleaned = []
    for (const element of this.form.elements) {
      if (element.name && element.value === "" && !element.disabled) {
        element.disabled = true
        this.cleaned.push(element)
      }
    }
    // Re-enable shortly after, in case the navigation was cancelled.
    setTimeout(() => {
      this.cleaned.forEach((element) => (element.disabled = false))
      this.cleaned = []
    }, 500)
  }

  submit() {
    this.form.requestSubmit()
  }

  get form() {
    return this.hasFormTarget ? this.formTarget : this.element
  }
}
