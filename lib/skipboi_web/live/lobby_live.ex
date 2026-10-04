defmodule SkipboiWeb.LobbyLive do
  use SkipboiWeb, :live_view

  alias Skipboi.Game
  alias Skipboi.Games

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    socket =
      assign(socket,
        page_title: "Skipboi",
        room_id: nil,
        state: %{},
        revision: 0,
        player_id: nil,
        lobby_full: false
      )

    case params do
      %{"id" => id} ->
        case Games.get(id) do
          {:ok, snapshot} ->
            socket = assign(socket, Map.put(snapshot, :room_id, id))

            if connected?(socket) do
              Games.subscribe(id)
              stored_player_id = get_connect_params(socket)["player_id"]

              cond do
                stored_player_id && snapshot.state[:players][stored_player_id] ->
                  {:ok, assign(socket, :player_id, stored_player_id)}

                map_size(snapshot.state[:players] || %{}) >= 5 ->
                  {:ok, assign(socket, :lobby_full, true)}

                true ->
                  {new_state, player_id} = Skipboi.Game.add_player(snapshot.state)

                  case Games.publish(id, snapshot.revision, new_state) do
                    {:ok, updated} ->
                      {:ok,
                       socket
                       |> assign(updated)
                       |> assign(:player_id, player_id)
                       |> push_event("store_player", %{room_id: id, player_id: player_id})}

                    _ ->
                      {:ok, unavailable(socket)}
                  end
              end
            else
              {:ok, socket}
            end

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
      <%= if @lobby_full do %>
        <main class="flex flex-col items-center gap-6 mt-12">
          <h1>This lobby is full, sorry!</h1>
          <.button id="go-home" phx-click="go_home" text="Back to home" />
        </main>
      <% else %>
        <main>
          <h1 class="mb-0">Game Lobby</h1>
          <span>Invite players with this link:</span>
          <div class="flex gap-4 items-center">
            <span>{url(~p"/lobby/#{@room_id}")}</span>
            <.button id="copy-link" class="w-fit gap-1" phx-click="copy_link" text="Copy Link">
              <Heroicons.document_duplicate aria-hidden="true" class="size-5" />
            </.button>
          </div>
          <p class="mb-0 font-bold">Players:</p>
          <div class="flex flex-col gap-2 ml-2 mb-4 mt-2">
            <span :for={{player_id, player} <- @state[:players]} class="flex gap-1 items-center">
              <Heroicons.user aria-hidden="true" class="size-5" />
              {player_id}
            </span>
          </div>
          <%= if map_size(@state[:players] || %{}) < 2 do %>
            <span class="border border-gray-400 rounded px-3 py-1 text-gray-500">Waiting for players...</span>
          <% else %>
            <.button id="start-game" phx-click="start_game" text="Start game">
              <Heroicons.arrow_right_circle aria-hidden="true" class="size-5" />
            </.button>
          <% end %>
        </main>
      <% end %>
    </Layouts.app>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("start_game", _, socket) do
    new_state = Game.start(socket.assigns.state)

    case update_game(socket, socket.assigns.revision, new_state) do
      {:ok, _snapshot} ->
        {:noreply, push_navigate(socket, to: ~p"/games/#{socket.assigns.room_id}")}

      {:error, _} ->
        {:noreply, unavailable(socket)}
    end
  end

  def handle_event("go_home", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/")}
  end

  def handle_event("copy_link", _, socket) do
    url = url(~p"/lobby/#{socket.assigns.room_id}")

    {:noreply,
     socket
     |> push_event("clipboard", %{text: url})
     |> put_flash(:info, "Link copied!")}
  end

  @impl Phoenix.LiveView
  def handle_info({:game_state, snapshot}, socket) do
    if snapshot.state[:started] do
      {:noreply, push_navigate(socket, to: ~p"/games/#{socket.assigns.room_id}")}
    else
      {:noreply, assign(socket, snapshot)}
    end
  end

  def handle_info(:game_ended, socket) do
    {:noreply, unavailable(socket)}
  end

  @impl Phoenix.LiveView
  def terminate(_reason, socket) do
    %{room_id: room_id, player_id: player_id} = socket.assigns

    if room_id && player_id do
      with {:ok, %{state: state, revision: revision}} <- Games.get(room_id),
           false <- state[:started] do
        new_state = Skipboi.Game.remove_player(state, player_id)
        Games.publish(room_id, revision, new_state)
      end
    end
  end

  defp update_game(socket, revision, state) do
    Games.publish(socket.assigns.room_id, revision, state)
  end

  defp unavailable(socket),
    do: put_flash(socket, :error, "This game has ended or expired. Create a new one above.")
end
