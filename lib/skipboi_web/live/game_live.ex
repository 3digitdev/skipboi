defmodule SkipboiWeb.GameLive do
  use SkipboiWeb, :live_view

  alias Skipboi.Card
  alias Skipboi.Game
  alias Skipboi.Games
  alias Skipboi.Player

  # ============================================================
  # DEBUG: fake game state for UI development. Access via ?debug
  # Remove this mount clause when no longer needed.
  # ============================================================
  @impl Phoenix.LiveView
  def mount(%{"id" => "debug"}, _session, socket), do: mount_debug(socket)
  def mount(params, session, socket), do: mount_real(params, session, socket)

  # ============================================================
  # DEBUG: fake game state for UI development. Access via ?debug
  # Remove this function when no longer needed.
  # ============================================================
  defp c(val, type \\ :number), do: %Card{value: val, type: type}

  defp mount_debug(socket) do
    player1 = %Player{
      id: "DebugAlice",
      hand: [c(3), c(7), c(nil, :skipbo), c(11), c(1)],
      # stock: [c(5), c(9), c(2), c(12), c(4), c(8), c(6), c(10), c(3), c(1)],
      stock: [c(5)],
      discards: {
        [c(4), c(2)],
        [c(9)],
        [],
        [c(6), c(nil, :skipbo), c(3)]
      }
    }

    player2 = %Player{
      id: "DebugBob",
      hand: [c(2), c(5), c(8)],
      stock: [c(7), c(11), c(1), c(6), c(3), c(12), c(9), c(2), c(8), c(5), c(4), c(10)],
      discards: {
        [c(7)],
        [],
        [c(11), c(3)],
        [c(1)]
      }
    }

    player3 = %Player{
      id: "DebugBill",
      hand: [c(2), c(5), c(8)],
      stock: [c(7), c(11), c(1), c(6), c(3), c(12), c(9), c(2), c(8), c(5), c(4), c(10)],
      discards: {
        [c(7)],
        [],
        [c(11), c(3)],
        [c(1)]
      }
    }

    player4 = %Player{
      id: "DebugBen",
      hand: [c(2), c(5), c(8)],
      stock: [c(7), c(11), c(1), c(6), c(3), c(12), c(9), c(2), c(8), c(5), c(4), c(10)],
      discards: {
        [c(7)],
        [],
        [c(11), c(3)],
        [c(1)]
      }
    }

    state = %{
      deck: Enum.map(1..80, fn v -> c(rem(v - 1, 12) + 1) end) |> Enum.shuffle(),
      players: %{
        "DebugAlice" => player1,
        "DebugBob" => player2,
        "DebugBill" => player3,
        "DebugBen" => player4
      },
      player_order: ["DebugAlice", "DebugBob", "DebugBill", "DebugBen"],
      current_player: "DebugAlice",
      started: true,
      room_id: "debug",
      host_id: "DebugAlice",
      discards: [],
      winner: nil,
      stacks: {
        [c(1), c(2), c(3)],
        [c(1, :skipbo), c(2)],
        [],
        []
      }
    }

    {:ok,
     assign(socket,
       page_title: "Skipboi (Debug)",
       room_id: "debug",
       state: state,
       revision: 0,
       player_id: "DebugAlice",
       player: player1,
       expanded_stack: nil,
       selected_card: nil
     )}
  end

  # ============================================================
  # END DEBUG
  # ============================================================

  defp mount_real(%{"id" => id}, _session, socket) do
    case Games.get(id) do
      {:ok, snapshot} ->
        socket =
          assign(
            socket,
            Map.merge(snapshot, %{
              page_title: "Skipboi",
              room_id: id,
              player_id: nil,
              player: nil,
              expanded_stack: nil,
              selected_card: nil
            })
          )

        if connected?(socket) do
          Games.subscribe(id)
          player_id = get_connect_params(socket)["player_id"]

          if player_id && snapshot.state[:players][player_id] do
            {:ok,
             assign(socket, player_id: player_id, player: snapshot.state[:players][player_id])}
          else
            {:ok, unavailable(socket)}
          end
        else
          {:ok, socket}
        end

      {:error, :not_found} ->
        {:ok, unavailable(socket)}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    assigns =
      assign(
        assigns,
        other_players: Enum.filter(assigns.state.players, &(elem(&1, 0) != assigns.player_id))
      )

    ~H"""
    <Layouts.app flash={@flash}>
      <main class="m-4 w-full flex flex-col items-center">
        <div class="flex justify-around gap-4 lg:justify-normal lg:gap-20 lg:ml-10 items-center mb-8">
          <div class="flex flex-col gap-2 content-center items-center">
            <.render_stacks state={@state} selected_card={@selected_card} />
            <div :if={@state.winner} class="flex flex-col gap-2 items-center">
              <h3 class="mb-0">🥇WINNER🥇</h3>
              <h4 class="mt-0">{@state.winner}</h4>
            </div>
          </div>
          <.section text="Opponents" side="left">
            <div class="flex flex-col gap-4">
              <.render_player
                :for={{id, player} <- @other_players}
                state={@state}
                id={id}
                player={player}
                player_id={@player_id}
                selected_card={@selected_card}
                expanded_stack={@expanded_stack}
              />
            </div>
          </.section>
        </div>
        <.render_player
          state={@state}
          id={@player_id}
          player={@player}
          player_id={@player_id}
          selected_card={@selected_card}
          expanded_stack={@expanded_stack}
        />
      </main>
    </Layouts.app>
    """
  end

  attr :state, :map, required: true
  attr :id, :string, required: true
  attr :player, :any, required: true
  attr :player_id, :string, required: true
  attr :selected_card, :boolean, default: false
  attr :expanded_stack, :boolean, default: false

  def render_player(assigns) do
    ~H"""
    <% is_me = @id == @player_id %>
    <div class={["flex flex-col gap-2 items-center w-fit", not is_me && "[zoom:0.75]"]}>
      <span class="font-bold">{@id}</span>
      <div class="flex gap-2 items-start">
        <% my_turn = is_me && @state.current_player == @player_id %>
        <.render_stock
          stock={@player.stock}
          my_turn={my_turn}
          selected_card={is_me && @selected_card}
          game_over={not is_nil(@state.winner)}
        />
        <.render_hand
          hand={@player.hand}
          my_turn={my_turn}
          selected_card={is_me && @selected_card}
          my_hand={is_me}
          game_over={not is_nil(@state.winner)}
        />
        <.render_discards
          discards={@player.discards}
          expanded_stack={@expanded_stack}
          player_id={@id}
          selected_card={is_me && @selected_card}
          game_over={not is_nil(@state.winner)}
        />
      </div>
    </div>
    """
  end

  attr :discards, :any
  attr :expanded_stack, :any
  attr :player_id, :string, required: true
  attr :selected_card, :any
  attr :game_over, :boolean, default: false

  def render_discards(assigns) do
    ~H"""
    <.section text="Discards" disabled={@game_over}>
      <div class="flex gap-2 items-center">
        <.discard_stack
          :for={{stack, idx} <- Enum.with_index(Tuple.to_list(@discards))}
          cards={stack}
          expanded={@expanded_stack == {@player_id, idx}}
          selected_card={@selected_card}
          click={%{source: "discard", stack: idx, player: @player_id}}
        />
      </div>
    </.section>
    """
  end

  attr :hand, :list
  attr :my_turn, :boolean, default: false
  attr :my_hand, :boolean, default: false
  attr :selected_card, :any
  attr :game_over, :boolean, default: false

  def render_hand(assigns) do
    ~H"""
    <.section text="Hand" disabled={@game_over}>
      <.card
        :for={{card, idx} <- Enum.with_index(@hand)}
        card={card}
        selected={@selected_card == {"hand", idx}}
        click={@my_turn && %{source: "hand", idx: idx}}
        hide_value={not @my_hand}
      />
      <%= if length(@hand) < 5 do %>
        <.card_slot :for={idx <- length(@hand)..4} />
      <% end %>
    </.section>
    """
  end

  attr :stock, :list
  attr :my_turn, :boolean, default: false
  attr :selected_card, :any
  attr :game_over, :boolean, default: false

  def render_stock(assigns) do
    assigns =
      assign(
        assigns,
        under_rot: if(length(assigns.stock) > 1, do: "rotate-5", else: ""),
        over_rot: if(length(assigns.stock) > 1, do: "-rotate-5", else: "")
      )

    ~H"""
    <.section text={"Stock (#{length(@stock)})"} disabled={@game_over} text_class="!text-xl">
      <span class={if(length(@stock) > 1, do: "bg-slate-700 p-[1px] rounded-md #{@under_rot}")}>
        <.card_slot :if={@stock == []} />
        <.card
          :if={@stock != []}
          card={hd(@stock)}
          class={@over_rot}
          selected={@selected_card == {"stock", 0}}
          click={@my_turn && %{source: "stock", idx: 0}}
        />
      </span>
    </.section>
    """
  end

  attr :state, :map
  attr :selected_card, :any, default: nil

  def render_stacks(assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-4 items-center">
      <%= for {stack, idx} <- @state.stacks |> Tuple.to_list() |> Enum.with_index() do %>
        <.stack
          large={true}
          cards={Enum.reverse(stack)}
          click={@selected_card && %{source: "stacks", idx: idx}}
        />
      <% end %>
    </div>
    """
  end

  # -- Card components --

  attr :cards, :list, required: true
  attr :click, :map, default: nil
  attr :large, :boolean, default: false

  def stack(%{large: true} = assigns) do
    assigns = assign(assigns, :has_under, length(assigns.cards) > 1)

    ~H"""
    <div class="relative h-24 w-18">
      <%= if @cards == [] do %>
        <.card_slot class="h-24 w-18" click={@click} />
      <% else %>
        <div :if={@has_under} class="absolute rotate-5">
          <.card
            card={Enum.at(@cards, 1)}
            class="!bg-slate-700 !border-slate-700 h-24 w-18"
          />
        </div>
        <div class="relative z-1">
          <.card card={hd(@cards)} click={@click} class="h-24 w-18" />
        </div>
      <% end %>
    </div>
    """
  end

  def stack(assigns) do
    assigns = assign(assigns, :has_under, length(assigns.cards) > 1)

    ~H"""
    <div class="relative h-16 w-12">
      <%= if @cards == [] do %>
        <.card_slot click={@click} />
      <% else %>
        <div :if={@has_under} class="absolute rotate-5">
          <.card
            card={Enum.at(@cards, 1)}
            class="!bg-slate-700 !border-slate-700"
          />
        </div>
        <div class="relative z-1">
          <.card card={hd(@cards)} click={@click} />
        </div>
      <% end %>
    </div>
    """
  end

  attr :cards, :list, required: true
  attr :expanded, :boolean, default: false
  attr :selected_card, :any, default: nil
  attr :click, :map, required: true

  def discard_stack(assigns) do
    assigns =
      assign(
        assigns,
        under_rot: if(length(assigns.cards) > 1, do: "rotate-5", else: ""),
        over_rot: if(length(assigns.cards) > 1, do: "-rotate-5", else: "")
      )

    ~H"""
    <div class="relative h-16 w-12 cursor-pointer">
      <.card_slot :if={@cards == []} click={@click} />
      <%= for {card, idx} <- Enum.with_index(Enum.reverse(@cards)) do %>
        <% under_card = not @expanded and idx < length(@cards) - 1 %>
        <div
          class={[
            "absolute w-full transition-all duration-100 ease-in-out",
            if(under_card, do: "p-[1px] rounded-md #{@under_rot}")
          ]}
          style={"top: #{if @expanded, do: idx * 16, else: 0}px; z-index: #{idx}; #{if under_card, do: "background-color: black"}"}
        >
          <.card
            card={card}
            under={idx < length(@cards) - 1}
            selected={@selected_card == {"discard", @click[:stack]} and idx == length(@cards) - 1}
            class={under_card && "!bg-slate-700 !border-slate-700"}
            click={@click && Map.put(@click, :idx, idx)}
          />
        </div>
      <% end %>
    </div>
    """
  end

  attr :card, :any, required: true
  attr :under, :boolean, default: false
  attr :selected, :boolean, default: false
  attr :click, :map, default: nil
  attr :hide_value, :boolean, default: false
  attr :class, :string, default: ""

  def card(assigns) do
    assigns =
      assigns
      |> assign(
        :color_class,
        cond do
          assigns.hide_value -> "bg-cyan-500 border border-cyan-700"
          assigns.card.type == :skipbo -> "bg-yellow-500 border border-yellow-700"
          assigns.card.value < 5 -> "bg-blue-500 border border-blue-700"
          assigns.card.value < 9 -> "bg-green-500 border border-green-700"
          assigns.card.value < 13 -> "bg-red-500 border border-red-700"
        end
      )
      |> assign(
        :num_pos_class,
        if(assigns.under,
          do: "text-[12px]",
          else: "text-2xl font-bold items-center justify-center"
        )
      )

    ~H"""
    <div
      class={[
        @color_class,
        "text-white w-12 h-16 rounded-md active:shadow-none flex select-none",
        @num_pos_class,
        @selected && not @under && "!outline-3 !outline-slate-700",
        @class
      ]}
      phx-click={@click && "click_card"}
      phx-value-source={@click && @click[:source]}
      phx-value-idx={@click && @click[:idx]}
      phx-value-stack={@click && @click[:stack]}
      phx-value-player={@click && @click[:player]}
    >
      <span class={[
        @under && "ml-2",
        @hide_value && "-rotate-10 text-[10pt] items-center flex flex-col"
      ]}>
        <%= cond do %>
          <% @hide_value -> %>
            <span>Skip</span><span>Bo!</span>
          <% @card.type == :skipbo && is_nil(@card.value) -> %>
            S
          <% true -> %>
            {@card.value}
        <% end %>
      </span>
    </div>
    """
  end

  attr :class, :string, default: ""
  attr :click, :map, default: nil
  slot :inner_block, required: false

  def card_slot(assigns) do
    ~H"""
    <div
      class={[
        "w-12 h-16 rounded-md border border-dashed flex items-center justify-center",
        @class
      ]}
      phx-click={@click && "click_card"}
      phx-value-source={@click && @click[:source]}
      phx-value-idx={@click && @click[:idx]}
      phx-value-stack={@click && @click[:stack]}
      phx-value-player={@click && @click[:player]}
    >
      <span>{render_slot(@inner_block)}</span>
    </div>
    """
  end

  # -- Events --

  @impl Phoenix.LiveView
  def handle_event("click_card", %{"source" => source} = params, socket) do
    dbg(params)
    idx = Map.get(params, "idx")
    idx = if(not is_nil(idx), do: String.to_integer(idx))
    clicked = {source, idx}
    stack_idx = Map.get(params, "stack")
    stack_idx = if(not is_nil(stack_idx), do: String.to_integer(stack_idx))

    socket =
      case {source, socket.assigns.selected_card} do
        {"discard", {"hand", hand_idx}} ->
          # Player is discarding from hand; turn is over
          player_discarded = Player.discard(socket.assigns.player, hand_idx, stack_idx)
          cur_state = socket.assigns.state

          new_state = %{
            cur_state
            | players: Map.put(cur_state.players, socket.assigns.player_id, player_discarded)
          }

          new_state = Game.next_turn(new_state)

          assign(socket,
            state: new_state,
            player: new_state.players[socket.assigns.player_id],
            selected_card: nil,
            expanded_stack: nil
          )

        {"stacks", {sel_src, sel_idx}} when sel_src != "stacks" ->
          dbg({sel_src, sel_idx})
          # Player is playing one of their cards on the stacks
          socket.assigns.player
          |> Player.play_card(
            socket.assigns.state,
            String.to_existing_atom(sel_src),
            idx,
            sel_idx
          )
          |> case do
            {:ok, {new_player, new_state}} ->
              assign(
                socket,
                state: %{
                  new_state
                  | players: Map.put(new_state.players, socket.assigns.player_id, new_player)
                },
                player: new_player,
                selected_card: nil,
                expanded_stack: nil
              )

            {err, _} ->
              dbg(err)
              put_flash(socket, :error, "Invalid play: #{err}")
          end

        {"discard", _} ->
          # Expand/collapse for viewing; only select if it's my pile on my turn
          player_id = params["player"]
          key = {player_id, stack_idx}
          expanded = if socket.assigns.expanded_stack == key, do: nil, else: key
          discard_clicked = {"discard", stack_idx}

          allow_selecting =
            player_id == socket.assigns.player_id &&
              socket.assigns.state.current_player == socket.assigns.player_id

          assign(socket,
            expanded_stack: expanded,
            selected_card:
              if(allow_selecting && socket.assigns.selected_card != discard_clicked,
                do: discard_clicked
              )
          )

        _ ->
          # Player is changing the selected card
          assign(socket,
            expanded_stack: nil,
            selected_card: if(socket.assigns.selected_card != clicked, do: clicked)
          )
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:game_state, snapshot}, socket) do
    {:noreply, assign(socket, snapshot)}
  end

  def handle_info(:game_ended, socket) do
    {:noreply, unavailable(socket)}
  end

  defp unavailable(socket) do
    socket
    |> put_flash(:error, "This game has ended or expired. Create a new one above.")
    |> push_navigate(to: ~p"/")
  end
end
