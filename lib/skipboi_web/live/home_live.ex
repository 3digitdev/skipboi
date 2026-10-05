defmodule SkipboiWeb.HomeLive do
  use SkipboiWeb, :live_view

  alias Skipboi.Games

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    socket = assign(socket, page_title: "Skipboi", room_id: nil, state: %{}, revision: 0)

    case params do
      %{"id" => id} ->
        if connected?(socket), do: Games.subscribe(id)

        case Games.get(id) do
          {:ok, snapshot} -> {:ok, assign(socket, Map.put(snapshot, :room_id, id))}
          {:error, :not_found} -> {:ok, unavailable(socket)}
        end

      _ ->
        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="flex flex-col items-center m-4">
        <h1 class="mb-0">Start a game of Skip-Bo</h1>
        <p class="italic mb-0">No account needed!</p>
        <p class="italic mt-0">Games last up to 24 hours and are deleted when ended.</p>
        <div class="flex flex-col gap-2 w-fit items-center">
          <div>
            <.button id="create-game" phx-click="create" text="Create game" />
          </div>
          <p class="mt-1 mb-0">Or, join someone else's game with their game link:</p>
          <div>
            <.form
              class="flex gap-2"
              for={to_form(%{"join-id" => ""})}
              id="join-form"
              phx-submit="join_game"
            >
              <.input id="join-id" name="join-id" placeholder="Enter game link" width="16" />
              <.button type="submit" id="join-game" text="Join game" />
            </.form>
          </div>
        </div>
      </main>
    </Layouts.app>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("create", _, socket) do
    id =
      Stream.cycle([1])
      |> Enum.reduce_while(nil, fn _, _ ->
        case Games.create() do
          {:error, :conflict} -> {:cont, nil}
          game_id -> {:halt, game_id}
        end
      end)

    {:noreply, push_navigate(socket, to: ~p"/lobby/#{id}")}
  end

  def handle_event("join_game", %{"join-id" => id}, socket) do
    id = Regex.run(~r/\/games\/([^\/]*)/, id, capture: :all_but_first) |> List.first() || id

    {:noreply,
     case Games.get(id) do
       {:ok, _} -> push_navigate(socket, to: ~p"/games/#{id}")
       {:error, _} -> unavailable(socket)
     end}
  end

  defp unavailable(socket),
    do: put_flash(socket, :error, "This game has ended or expired. Create a new one above.")
end
