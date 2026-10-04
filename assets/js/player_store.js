const KEY = "skipboi_players"

function getAll() {
  try {
    return JSON.parse(sessionStorage.getItem(KEY)) || {}
  } catch {
    return {}
  }
}

function save(store) {
  sessionStorage.setItem(KEY, JSON.stringify(store))
}

export function getPlayerId(roomId) {
  return getAll()[roomId] || null
}

export function setPlayerId(roomId, playerId) {
  const store = getAll()
  store[roomId] = playerId
  save(store)
}

export function removePlayerId(roomId) {
  const store = getAll()
  delete store[roomId]
  save(store)
}
