import { Controller } from "@hotwired/stimulus"

// Optional progressive enhancement for a has_one attachment field: when you
// pick a replacement file, uncheck the "keep current" box so the upload wins.
// Without it the form still works — you just uncheck "keep" yourself to replace.
export default class extends Controller {
  static targets = ["keep"]

  replace() {
    this.keepTargets.forEach((keep) => (keep.checked = false))
  }
}
