defmodule SkipboiWeb.GameLive do
  use SkipboiWeb, :live_view

  alias Skipboi.Game
  alias Skipboi.Games
  alias Skipboi.Player

  @impl Phoenix.LiveView
  def mount(params, session, socket), do: mount_real(params, session, socket)

  defp mount_real(%{"id" => id}, _session, socket) do
    case Games.get(id) do
      {:ok, snapshot} ->
        socket =
          socket
          |> assign(
            Map.merge(snapshot, %{
              page_title: "Skipboi",
              room_id: id,
              player_id: nil,
              player: nil,
              expanded_stack: nil,
              selected_card: nil,
              tray_open: false,
              mobile: false
            })
          )
          |> compute_other_players()

        if connected?(socket) do
          Games.subscribe(id)
          player_id = get_connect_params(socket)["player_id"]
          viewport_width = get_connect_params(socket)["viewport_width"] || 1024
          mobile = viewport_width < 768

          if player_id && snapshot.state[:players][player_id] do
            {:ok,
             socket
             |> assign(
               player_id: player_id,
               player: snapshot.state[:players][player_id],
               mobile: mobile
             )
             |> compute_other_players()}
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

  defp publish_or_apply(socket, new_state) do
    if new_state.current_player != socket.assigns.state.current_player do
      Phoenix.PubSub.broadcast(
        Skipboi.PubSub,
        Games.topic(socket.assigns.room_id),
        {:notify, new_state.current_player}
      )
    end

    case Games.publish(socket.assigns.room_id, socket.assigns.revision, new_state) do
      {:ok, _snapshot} ->
        assign(socket, selected_card: nil, expanded_stack: nil)

      {:error, :conflict} ->
        put_flash(socket, :error, "Another player moved first, try again.")
    end
  end

  defp compute_other_players(socket) do
    assign(
      socket,
      :other_players,
      socket.assigns.state.player_order
      |> Enum.reject(&(&1 == socket.assigns.player_id))
      |> Enum.map(&{&1, socket.assigns.state.players[&1]})
    )
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <%= if is_nil(@player) do %>
        <div class="flex items-center justify-center mt-12 text-lg">Loading game...</div>
      <% else %>
        <div class="bg-cyan-500 text-white text-center text-sm font-bold py-1 -mx-2 -mt-2">
          {if(@state.current_player == @player_id, do: "Your", else: "#{@state.current_player}'s")} turn
        </div>
        <div
          id="reaction-feed"
          phx-hook=".ReactionFeed"
          phx-update="ignore"
          class="fixed top-12 left-3 z-50 flex flex-col gap-1 pointer-events-none"
        >
        </div>
        <script :type={Phoenix.LiveView.ColocatedHook} name=".ReactionFeed">
          export default {
            mounted() {
              this.handleEvent("reaction", ({player, emoji}) => {
                const el = document.createElement("div")
                el.style.cssText = "display:flex;align-items:center;gap:6px;background:rgba(30,41,59,0.85);color:white;font-size:14px;padding:6px 12px;border-radius:9999px;width:fit-content;backdrop-filter:blur(4px);opacity:1;transition:opacity 0.5s ease-out"
                el.innerHTML = `<span style="font-size:20px">${emoji}</span><span style="font-weight:500">${player}</span>`
                this.el.appendChild(el)
                setTimeout(() => { el.style.opacity = "0" }, 2500)
                setTimeout(() => el.remove(), 3000)
              })
              this.handleEvent("notify", ({player}) => {
                const el = document.createElement("div")
                el.style.cssText = "display:flex;align-items:center;gap:6px;background:rgba(0,184,219,0.85);color:white;font-size:14px;padding:6px 12px;border-radius:9999px;width:fit-content;backdrop-filter:blur(4px);opacity:1;transition:opacity 0.5s ease-out"
                el.innerHTML = `<span style="font-size:20px">‼️</span><span style="font-weight:500">Your turn, ${player}!</span>`
                this.el.appendChild(el)
                setTimeout(() => { el.style.opacity = "0" }, 2500)
                setTimeout(() => el.remove(), 3000)

              })
            }
          }
        </script>
        <%= if not @mobile do %>
          <main class="flex m-4 w-full flex-col items-center">
            <div class="flex justify-around gap-4 lg:justify-normal lg:gap-20 lg:ml-10 items-center mb-8">
              <div class="flex flex-col gap-2 content-center items-center">
                <%= if @state.winner do %>
                  <span class="flex flex-col items-center gap-2">
                    <div class="flex flex-col gap-2 items-center bg-amber-500/50 p-2 mt-8 rounded-md">
                      <h1 class="mb-0 mt-0">🥇WINNER🥇</h1>
                      <h2 class="mb-0 mt-0">{@state.winner}</h2>
                    </div>
                    <.button text="Rematch!" type="button" phx-click="rematch" />
                  </span>
                <% else %>
                  <.render_stacks state={@state} selected_card={@selected_card} />
                <% end %>
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
            <div class="flex rounded-full overflow-hidden mt-8">
              <button
                :for={emoji <- ["👍", "😂", "😮", "😭", "👎"]}
                type="button"
                phx-click="react"
                phx-value-reaction={emoji}
                class="text-3xl hover:scale-125 transition-transform cursor-pointer bg-amber-300/30 py-2 px-3 border-y-0 border-r-0 first:border-l-0 outline-none hover:bg-amber-300 active:bg-amber-300"
              >{emoji}</button>
            </div>
          </main>
        <% else %>
          <%!-- Mobile layout --%>
          <main class="flex flex-col items-center gap-4 p-4 pb-16">
            <div class="flex rounded-full overflow-hidden mb-4 mt-2">
              <button
                :for={emoji <- ["👍", "😂", "😮", "😭", "👎"]}
                type="button"
                phx-click="react"
                phx-value-reaction={emoji}
                class="text-3xl hover:scale-125 transition-transform cursor-pointer bg-amber-300/30 py-2 px-3 border-y-0 border-r-0 first:border-l-0 outline-none hover:bg-amber-300 active:bg-amber-300"
              >{emoji}</button>
            </div>
            <%= if @state.winner do %>
              <div class="flex flex-col gap-2 items-center bg-amber-300/50 p-2 mt-8 rounded-md">
                <h1 class="mb-0 mt-0">🥇WINNER🥇</h1>
                <h2 class="mb-0 mt-0">{@state.winner}</h2>
              </div>
              <.button text="Rematch!" type="button" phx-click="rematch" />
            <% else %>
              <.render_stacks state={@state} selected_card={@selected_card} />
            <% end %>
            <% my_turn = @state.current_player == @player_id %>
            <.render_hand
              hand={@player.hand}
              my_turn={my_turn}
              selected_card={@selected_card}
              my_hand={true}
              game_over={not is_nil(@state.winner)}
            />
            <div class="flex gap-2 items-start">
              <.render_stock
                stock={@player.stock}
                my_turn={my_turn}
                selected_card={@selected_card}
                game_over={not is_nil(@state.winner)}
              />
              <.render_discards
                discards={@player.discards}
                expanded_stack={@expanded_stack}
                player_id={@player_id}
                selected_card={@selected_card}
                game_over={not is_nil(@state.winner)}
              />
            </div>
          </main>

          <%!-- Mobile opponent tray --%>
          <div class="fixed bottom-0 left-0 right-0 z-50 pb-[env(safe-area-inset-bottom)] bg-slate-800">
            <button
              class="w-full bg-slate-800 text-white text-sm py-2 flex items-center justify-center gap-1"
              phx-click="toggle_tray"
            >
              <span>Opponents ({length(@other_players)})</span>
              <span class={["transition-transform", @tray_open && "rotate-180"]}>&#9650;</span>
            </button>
            <div class={[
              "bg-white overflow-y-auto transition-all duration-200 ease-in-out",
              if(@tray_open, do: "max-h-[50vh] h-auto", else: "h-0")
            ]}>
              <div class="flex flex-col gap-6 p-4 items-center">
                <.render_player
                  :for={{id, player} <- @other_players}
                  state={@state}
                  id={id}
                  player={player}
                  player_id={@player_id}
                  selected_card={@selected_card}
                  expanded_stack={@expanded_stack}
                  vertical
                />
              </div>
            </div>
          </div>
        <% end %>
      <% end %>
    </Layouts.app>
    """
  end

  attr :state, :map, required: true
  attr :id, :string, required: true
  attr :player, :any, required: true
  attr :player_id, :string, required: true
  attr :selected_card, :boolean, default: false
  attr :expanded_stack, :boolean, default: false
  attr :vertical, :boolean, default: false

  def render_player(assigns) do
    ~H"""
    <% is_me = @id == @player_id %>
    <% my_turn = is_me && @state.current_player == @player_id %>
    <% is_current = @id == @state.current_player %>
    <div class={[
      "flex flex-col gap-2 items-center w-fit",
      not is_me && not @vertical && "[zoom:0.75]"
    ]}>
      <span class={["font-bold", is_current && "text-cyan-500"]}>
        <span :if={is_current}>👉 </span>{@id}<span :if={is_current}> 👈</span>
      </span>
      <%= if @vertical do %>
        <.render_hand
          hand={@player.hand}
          my_turn={my_turn}
          selected_card={is_me && @selected_card}
          my_hand={is_me}
          game_over={not is_nil(@state.winner)}
        />
        <div class="flex gap-2 items-start">
          <.render_stock
            stock={@player.stock}
            my_turn={my_turn}
            selected_card={is_me && @selected_card}
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
      <% else %>
        <div class="flex gap-2 items-start">
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
      <% end %>
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
    <.section text={"Stock (#{length(@stock)})"} disabled={@game_over} text_class="!text-lg">
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
          do: "text-[12px] font-bold",
          else: "text-2xl font-bold items-center justify-center"
        )
      )

    ~H"""
    <div
      class={[
        @color_class,
        "text-white w-12 h-16 rounded-md flex select-none",
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
    idx = Map.get(params, "idx")
    idx = if(not is_nil(idx), do: String.to_integer(idx))
    clicked = {source, idx}
    stack_idx = Map.get(params, "stack")
    stack_idx = if(not is_nil(stack_idx), do: String.to_integer(stack_idx))

    socket =
      case {source, socket.assigns.selected_card} do
        {"discard", {"hand", hand_idx}} ->
          player_discarded = Player.discard(socket.assigns.player, hand_idx, stack_idx)
          cur_state = socket.assigns.state

          new_state =
            %{
              cur_state
              | players: Map.put(cur_state.players, socket.assigns.player_id, player_discarded)
            }
            |> Game.next_turn()

          publish_or_apply(socket, new_state)

        {"stacks", {sel_src, sel_idx}} when sel_src != "stacks" ->
          socket.assigns.player
          |> Player.play_card(
            socket.assigns.state,
            String.to_existing_atom(sel_src),
            idx,
            sel_idx
          )
          |> case do
            {:ok, {new_player, new_state}} ->
              full_state = %{
                new_state
                | players: Map.put(new_state.players, socket.assigns.player_id, new_player)
              }

              publish_or_apply(socket, full_state)

            {err, _} ->
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

  def handle_event("toggle_tray", _, socket) do
    {:noreply, assign(socket, tray_open: !socket.assigns.tray_open)}
  end

  def handle_event("react", %{"reaction" => emoji}, socket) do
    Phoenix.PubSub.broadcast(
      Skipboi.PubSub,
      Games.topic(socket.assigns.room_id),
      {:reaction, socket.assigns.player_id, emoji}
    )

    {:noreply, socket}
  end

  def handle_event("rematch", _, socket) do
    player_shells =
      socket.assigns.state.player_order
      |> Map.new(fn id ->
        {id, %Player{id: id, hand: [], stock: [], discards: {[], [], [], []}}}
      end)

    new_state =
      Game.new_game()
      |> Map.merge(%{
        room_id: socket.assigns.state.room_id,
        host_id: socket.assigns.state.host_id,
        players: player_shells
      })
      |> Game.start()

    {:noreply, publish_or_apply(socket, new_state)}
  end

  @impl Phoenix.LiveView
  def handle_info({:game_state, snapshot}, socket) do
    player =
      if socket.assigns.player_id,
        do: snapshot.state.players[socket.assigns.player_id]

    was_my_turn = socket.assigns.state.current_player == socket.assigns.player_id
    is_my_turn = snapshot.state.current_player == socket.assigns.player_id

    tray_open =
      cond do
        not socket.assigns.mobile -> socket.assigns.tray_open
        is_my_turn -> false
        was_my_turn && not is_my_turn -> true
        true -> socket.assigns.tray_open
      end

    {:noreply,
     socket
     |> assign(snapshot)
     |> assign(
       player: player,
       selected_card: nil,
       expanded_stack: nil,
       tray_open: tray_open
     )
     |> compute_other_players()}
  end

  def handle_info({:notify, player_id}, socket) do
    socket =
      if player_id == socket.assigns.player_id do
        push_event(socket, "notify", %{player: player_id})
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:reaction, player_id, emoji}, socket) do
    {:noreply, push_event(socket, "reaction", %{player: player_id, emoji: emoji})}
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
