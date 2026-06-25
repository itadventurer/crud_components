import { Controller } from "@hotwired/stimulus"

// Optional progressive enhancement for the CrudComponents column picker:
// drag the rows to reorder columns. Without this controller the picker still
// works — ticked checkboxes submit `cols[]` in their listed order; you just
// can't reorder by dragging. Submission order = DOM order of the <li>s, so
// reordering the list is all this does.
export default class extends Controller {
  static targets = ["list", "item"]

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
