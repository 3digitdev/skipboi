// Put game-specific move validation here. The server does not enforce game rules.
export function validateState(state) {
  if (state === null || Array.isArray(state) || typeof state !== "object") {
    throw new Error("State must be a JSON object.")
  }
  if (new TextEncoder().encode(JSON.stringify(state)).length > 65536) {
    throw new Error("State must be no larger than 64 KiB.")
  }
  return state
}

export function incrementScore(state) {
  if (!Number.isSafeInteger(state.score) || state.score < 0 || state.score >= Number.MAX_SAFE_INTEGER) {
    throw new Error("The demo needs a non-negative integer score that can be incremented safely.")
  }
  return validateState({...state, score: state.score + 1})
}

export const GameState = {
  mounted() {
    this.editor = this.el.querySelector("#state-json")
    this.status = this.el.querySelector("#editor-status")
    this.busy = false
    this.online = true
    this.readState()
    this.loadDraft()
    this.el.querySelector("#load-state").onclick = () => this.loadDraft()
    this.el.querySelector("#state-form").onsubmit = event => {
      event.preventDefault()
      this.send(() => validateState(JSON.parse(this.editor.value)), this.draftRevision)
    }
    this.el.querySelector("#increment").onclick = () => this.send(() => incrementScore(this.state), this.revision)
  },
  updated() {
    this.readState()
  },
  disconnected() {
    this.online = false
    this.status.textContent = "Disconnected. Wait for the connection to return."
  },
  reconnected() {
    this.online = true
    this.busy = false
    this.status.textContent = "Reconnected. Load latest before publishing an old draft."
  },
  readState() {
    this.state = JSON.parse(this.el.dataset.state)
    this.revision = Number(this.el.dataset.revision)
  },
  loadDraft() {
    this.editor.value = JSON.stringify(this.state, null, 2)
    this.draftRevision = this.revision
    this.status.textContent = "Loaded revision " + this.revision + "."
  },
  send(buildState, revision) {
    if (this.busy || !this.online) return
    try {
      const json = JSON.stringify(buildState())
      this.busy = true
      this.status.textContent = "Sending…"
      this.pushEvent("publish", {json, revision}, reply => {
        this.busy = false
        this.status.textContent = reply.error || "State shared. Load latest before editing again."
      })
    } catch (error) {
      this.status.textContent = error.message
    }
  }
}
