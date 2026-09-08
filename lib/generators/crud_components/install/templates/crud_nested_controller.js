import { Controller } from "@hotwired/stimulus"

// A nested row's "remove" box, made a button. Without this controller the box
// is a plain checkbox with a label: tick it, save, the row is gone. With it,
// the box hides, the button shows, and clicking it does both at once — the row
// disappears straight away and comes back only if the save fails.
export default class extends Controller {
  static targets = ["destroy", "flag", "button"]

  connect() {
    this.destroyTarget.hidden = true
    this.buttonTarget.hidden = false
    this.sync()
  }

  remove() {
    this.flagTarget.checked = true
    this.sync()
  }

  toggle() {
    this.sync()
  }

  sync() {
    this.element.hidden = this.flagTarget.checked
  }
}
