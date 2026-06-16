import { Controller } from "@hotwired/stimulus"

// Optional progressive enhancement for selectable collections: a "select all"
// (visible rows) and per-group master checkbox, plus a live "N selected" count.
// The row checkboxes submit selected[] without this — it just spares the
// clicking. The bulk-action buttons post the form regardless.
export default class extends Controller {
  static targets = ["row", "all", "group", "count", "button"]

  connect() { this.update() }

  toggleAll() {
    this.rowTargets.forEach((row) => (row.checked = this.allTarget.checked))
    this.update()
  }

  toggleGroup(event) {
    const key = event.target.dataset.group
    this.rowTargets.forEach((row) => {
      if (row.dataset.group === key) row.checked = event.target.checked
    })
    this.update()
  }

  update() {
    const count = this.rowTargets.filter((row) => row.checked).length
    if (this.hasAllTarget) {
      this.allTarget.checked = count > 0 && count === this.rowTargets.length
      this.allTarget.indeterminate = count > 0 && count < this.rowTargets.length
    }
    if (this.hasCountTarget) this.countTarget.textContent = `${count} selected`
    // disable the bulk-action buttons while nothing is selected
    this.buttonTargets.forEach((button) => (button.disabled = count === 0))
  }
}
