defmodule SkipboiWeb.GameLive do
  use SkipboiWeb, :live_view

  alias Skipboi.Games
  alias Heroicons

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    socket = assign(socket, page_title: "Skipboi", room_id: nil, state: %{}, revision: 0)

    case params do
      %{"id" => id} ->
        player_id =
          UniqueNamesGenerator.generate([:adjectives, :names], %{style: :capital, separator: ""})

        if connected?(socket), do: Games.subscribe(id)

        case Games.get(id) do
          {:ok, %{state: %{"started" => true}}} ->
            {:ok, unavailable(socket)}

          {:ok, snapshot} ->
            # setup initial game state
            snapshot =
              Map.merge(
                snapshot,
                %{
                  state: %{
                    "players" => [player_id | snapshot.state["players"] || []] |> Enum.uniq(),
                    "room_id" => id
                  }
                }
              )

            {:ok,
             socket
             |> assign(:room_id, id)
             |> assign(:player_id, player_id)
             |> then(fn socket ->
               socket
               |> update_game(snapshot.revision, snapshot.state)
               |> case do
                 {:ok, snapshot} -> assign(socket, snapshot)
                 {:error, :conflict} -> unavailable(socket)
                 {:error, :invalid_state} -> unavailable(socket)
                 {:error, :not_found} -> unavailable(socket)
               end
             end)}

          {:error, :not_found} ->
            {:ok, unavailable(socket)}
        end

      _ ->
        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main>
        <section
          id="game"
          phx-hook="GameState"
          data-state={Jason.encode!(@state)}
          data-revision={@revision}
        >
          <%= case dbg(@state) do %>
            <% %{"started" => true} -> %>
              <.render_game room_id={@room_id} state={@state} revision={@revision} />
            <% _ -> %>
              <.render_lobby room_id={@room_id} state={@state} revision={@revision} />
          <% end %>
          <p>Anyone with the link can update or end this game.</p>

          <h2>Shared state v{@revision}</h2>
          <pre id="shared-state">{Jason.encode!(@state, pretty: true)}</pre>
          <.button id="increment">Add one to score</.button>
          <p>Try this from two windows. The browser calculates the next score.</p>

          <.form for={to_form(%{"json" => ""})} id="state-form" phx-update="ignore">
            <p><label for="state-json">Edit JSON state</label></p>
            <.input
              type="textarea"
              id="state-json"
              name="json"
              rows="10"
              spellcheck="false"
              aria-describedby="editor-help"
            />
            <p id="editor-help">
              Any JSON object, up to 64 KiB. Load the latest state to discard your draft.
            </p>
            <.button id="publish-state" type="submit">Publish state</.button>
            <.button id="load-state">Load latest</.button>
            <p id="editor-status" role="status" aria-live="polite"></p>
          </.form>

          <.button
            id="end-game"
            phx-click="finish"
            data-confirm="End this game for everyone and delete its state?"
          >
            End game <Heroicons.no_symbol aria-hidden="true" class="size-5" />
          </.button>
        </section>
      </main>
    </Layouts.app>
    """
  end

  attr :state, :any, required: true
  attr :revision, :integer, required: true
  attr :room_id, :string, required: true

  defp render_game(assigns) do
    ~H"""
    <h1>Let's play Skip-Bo!</h1>
    <p>Game state: {inspect(@state)}</p>
    """
  end

  attr :state, :any, required: true
  attr :revision, :integer, required: true
  attr :room_id, :string, required: true

  defp render_lobby(assigns) do
    ~H"""
    <div class="flex flex-col gap-1">
      <span>Invite players with this link:</span>
      <span>{url(~p"/games/#{@room_id}")}</span>
      <.button id="copy-link" class="w-fit gap-1" phx-click="copy_link">
        Copy link <Heroicons.document_duplicate aria-hidden="true" class="size-5" />
      </.button>
      <p class="mb-0 font-bold">Players:</p>
      <div class="flex flex-col gap-1 ml-2">
        <span :for={player <- @state["players"] || []} class="flex gap-1 items-center">
          <Heroicons.user aria-hidden="true" class="size-5" />
          {player}
        </span>
      </div>
      <.button
        id="start-game"
        class="w-fit mt-4"
        phx-click="start_game"
        disabled={length(@state["players"]) < 2}
      >
        Start game <Heroicons.arrow_right_circle aria-hidden="true" class="size-5" />
      </.button>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("create", _, socket) do
    id =
      Stream.cycle([1])
      |> Enum.reduce_while(nil, fn _, _ ->
        case Games.create() do
          {:error, :conflict} -> {:cont, nil}
          {:ok, id} -> {:halt, id}
        end
      end)

    {:noreply, push_navigate(socket, to: ~p"/games/#{id}")}
  end

  def handle_event("join_game", %{"join-id" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/games/#{id}")}
  end

  def handle_event("publish", %{"revision" => revision, "json" => json}, socket) do
    case update_game(socket, revision, json) do
      {:ok, snapshot} ->
        {:reply, %{ok: true}, assign(socket, snapshot)}

      {:error, :conflict} ->
        {:reply,
         %{error: "Another player updated the state. Review the latest state and try again."},
         socket}

      {:error, :invalid_state} ->
        {:reply, %{error: "Send a JSON object no larger than 64 KiB."}, socket}

      {:error, :not_found} ->
        {:reply, %{error: "This game has ended."}, unavailable(socket)}
    end
  end

  def handle_event("start_game", _, socket) do
    {:noreply,
     socket
     |> assign(:state, Map.put(socket.assigns.state, "started", true))
     |> then(fn socket ->
       socket
       |> update_game(socket.assigns.revision, Map.put(socket.assigns.state, "started", true))
       |> case do
         {:ok, snapshot} -> assign(socket, snapshot)
         {:error, :conflict} -> unavailable(socket)
         {:error, :invalid_state} -> unavailable(socket)
         {:error, :not_found} -> unavailable(socket)
       end
     end)}
  end

  def handle_event("finish", _, socket) do
    Games.finish(socket.assigns.room_id)
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  @impl Phoenix.LiveView
  def handle_info({:game_state, snapshot}, socket) do
    if snapshot.revision > socket.assigns.revision,
      do: {:noreply, assign(socket, snapshot)},
      else: {:noreply, socket}
  end

  def handle_info(:game_ended, socket), do: {:noreply, unavailable(socket)}

  defp unavailable(socket) do
    socket
    |> put_flash(:error, "This game has ended or expired. Create a new one above.")
    |> push_navigate(to: ~p"/")
  end

  defp update_game(socket, revision, state) do
    Games.publish(socket.assigns.room_id, revision, state)
  end
end
