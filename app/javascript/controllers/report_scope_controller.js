import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "recipientGroup"]

  change() {
    this.recipientGroupTargets.forEach((group) => {
      const selected = group.dataset.scope === this.selectTarget.value
      group.hidden = !selected
      group.querySelectorAll("input[type=checkbox]").forEach((input) => {
        input.disabled = !selected
      })
    })
  }
}
