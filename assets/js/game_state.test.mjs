import {test} from "node:test"
import assert from "node:assert/strict"
import {incrementScore, validateState} from "./game_state.mjs"

test("the browser computes a move without mutating its current state", () => {
  const state = {score: 2, cards: [1, 4]}
  assert.deepEqual(incrementScore(state), {score: 3, cards: [1, 4]})
  assert.equal(state.score, 2)
})

test("rejects invalid demo moves and JSON envelopes", () => {
  for (const score of [-1, 0.5, "1", Number.MAX_SAFE_INTEGER]) {
    assert.throws(() => incrementScore({score}))
  }
  for (const state of [null, [], "text", {text: "x".repeat(65536)}]) {
    assert.throws(() => validateState(state))
  }
})
