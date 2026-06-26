import { Controller } from "@hotwired/stimulus"

// Optional progressive enhancement for the CrudComponents column picker:
// - drag the rows to reorder columns
// - on submit, collapse the `cols[]=a&cols[]=b` array into a single `cols=a,b`
//   for a prettier, shareable URL (the server reads both forms)
// Without this controller the picker still works — ticked checkboxes submit
// `cols[]` in their listed order; you just can't reorder by dragging, and the
// URL keeps the repeated `cols[]` form. Submission order = DOM order of the <li>s.
export default class extends Controller {
  static targets = ["list", "item"]

  // Rewrite the checked cols[] boxes into one comma-joined hidden field per param
  // group (handles param_prefix). Mirrors crud-filter#clean: mutate during the
  // submit event so the browser serializes the rewritten form, then restore
  // shortly after in case the navigation was cancelled.
  clean(event) {
    const form = event.target
    this.injected = []
    this.disabledBoxes = []
    const groups = new Map() // base name (without []) -> [values] in DOM order

    for (const box of form.querySelectorAll('input[type=checkbox][name$="[]"]')) {
      const base = box.name.slice(0, -2)
      this.disabledBoxes.push(box)
      box.disabled = true // drop the array form from this submit
      if (box.checked) (groups.get(base) || groups.set(base, []).get(base)).push(box.value)
    }
    for (const [base, values] of groups) {
      const hidden = document.createElement("input")
      hidden.type = "hidden"
      hidden.name = base
      hidden.value = values.join(",")
      form.appendChild(hidden)
      this.injected.push(hidden)
    }
    setTimeout(() => {
      this.injected.forEach((n) => n.remove())
      this.disabledBoxes.forEach((b) => (b.disabled = false))
      this.injected = this.disabledBoxes = []
    }, 500)
  }

  connect() {
    this.dragging = null
  }

  itemTargetConnected(item) {
    item.addEventListener("dragstart", (e) => this.start(e, item))
    item.addEventListener("dragover", (e) => this.over(e, item))
    item.addEventListener("dragend", () => this.end(item))
  }

  start(event, item) {
    this.dragging = item
    item.classList.add("is-dragging")
    event.dataTransfer.effectAllowed = "move"
  }

  over(event, item) {
    event.preventDefault()
    if (!this.dragging || this.dragging === item) return
    const rect = item.getBoundingClientRect()
    const after = event.clientY - rect.top > rect.height / 2
    item.parentNode.insertBefore(this.dragging, after ? item.nextSibling : item)
  }

  end(item) {
    item.classList.remove("is-dragging")
    this.dragging = null
  }

  // A checkbox toggled with nothing else to do — kept so the markup's
  // data-action has a handler and future enhancements have a hook.
  toggle() {}
}
