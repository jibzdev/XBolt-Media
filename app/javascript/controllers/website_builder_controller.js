import { Controller } from "@hotwired/stimulus"

// Legacy controller kept so old cached pages don't throw.
// Live editing is handled by website_live_editor_controller.js
export default class extends Controller {
  connect() {
    // no-op
  }
}
