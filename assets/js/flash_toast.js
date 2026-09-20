export const FlashToast = {
  mounted() {
    this.pause = () => clearTimeout(this.timer)
    this.resume = () => this.schedule()
    this.el.addEventListener("mouseenter", this.pause)
    this.el.addEventListener("mouseleave", this.resume)
    this.el.addEventListener("focusin", this.pause)
    this.el.addEventListener("focusout", this.resume)
    this.message = this.el.dataset.message
    this.schedule()
  },

  updated() {
    if (this.message !== this.el.dataset.message) {
      this.message = this.el.dataset.message
      this.schedule()
    }
  },

  schedule() {
    clearTimeout(this.timer)
    if (this.el.matches(":hover") || this.el.contains(document.activeElement)) return
    this.timer = setTimeout(() => {
      this.pushEvent("lv:clear-flash", {key: this.el.dataset.kind})
    }, Number(this.el.dataset.timeout))
  },

  disconnected() { clearTimeout(this.timer) },
  reconnected() { this.schedule() },

  destroyed() {
    clearTimeout(this.timer)
    this.el.removeEventListener("mouseenter", this.pause)
    this.el.removeEventListener("mouseleave", this.resume)
    this.el.removeEventListener("focusin", this.pause)
    this.el.removeEventListener("focusout", this.resume)
  }
}
