# Skipboi

Minimal Phoenix 1.8 / LiveView 1.2 app with Tailwind CSS 4 available and an unstyled,
browser-owned JSON state demo. No authentication, database, or Node package
installation is required to run the app.

## Run

Use the Elixir/Erlang versions in `.tool-versions`, then:

```sh
mix setup
mix phx.server
```

Open http://localhost:4000, create a game, and open its invite link in another
window. Tap **Add one to score** on either screen, or edit a JSON object and
publish it. A newly joined browser receives the latest state. **Load latest**
refreshes the editor; incoming updates preserve an unfinished draft.

Tailwind and esbuild watch assets in development. Utility classes in HEEx and
JavaScript are scanned by `assets/css/app.css`. Use complete class names rather
than constructing class fragments dynamically. Run `mix assets.deploy` for
minified production assets. Preflight is omitted so the page uses native browser
styles. `CoreComponents` contains only unstyled text-input (including textarea)
and button wrappers, used by the main view.

## Phones and tablets on your local network

In `config/dev.exs`, change the HTTP IP to `{0, 0, 0, 0}` and restart. Open
`http://YOUR_COMPUTER_LAN_IP:4000` on devices on the same network. The game page
uses the current browser's origin for its invitation link. The page retains a mobile viewport and uses plain HTML with native controls. Development mode is intended for a trusted local network.

## Shared state

- `assets/js/game_state.mjs`: browser-side JSON validation and demo moves. Add
  your game rules here. The server does not enforce those rules.
- `lib/skipboi/games.ex`: supervised in-memory relay and `game:<room_id>` PubSub
  topics. `create/0`, `subscribe/1`, `get/1`, `publish/3`, and `finish/1` provide
  the room API. LiveView carries messages between browsers and PubSub.
- `lib/skipboi_web/live/game_live.ex`: room lifecycle, event handling, and UI.

Each update replaces the entire JSON object (maximum 64 KiB). Updates carry the
revision used to build them. The server serializes writes and rejects stale
revisions; clients should load the latest state and reapply their move. This
prevents silent lost updates without imposing game rules. Future server-side
verification can be added before accepting state in `Games.publish/3`'s handler.

Rooms expire 24 hours after creation, without extending that deadline on activity.
Ending a game deletes its state immediately and redirects connected players.
Rooms also disappear when the relay or application restarts. This is a single-node
starter; multiple app instances require shared room ownership/storage before
scaling out. Nothing is saved after a game ends, and missing links do not recreate
rooms. Anyone with the random invite link can read, modify, or end that game.

## Checks

```sh
mix test
node --test assets/js/game_state.test.mjs
mix format --check-formatted
mix assets.deploy
```

Elixir tests are colocated with their modules under `lib/`; shared test support
stays in `test/`. Tests cover multiple LiveViews, late joins, stale revisions,
JSON limits, room isolation, ending, expiry, and browser move validation.
