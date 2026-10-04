defmodule Skipboi.Game do
  alias Skipboi.Card
  alias Skipboi.Player

  @enforce_keys [:revision, :expires_at, :timer, :state]
  defstruct [:revision, :expires_at, :timer, :state]

  @type state() :: %{
          players: %{String.t() => Player.t()},
          started: boolean(),
          room_id: String.t() | nil,
          host_id: String.t() | nil,
          deck: [Card.t()],
          player_order: [String.t()],
          current_player: String.t() | nil,
          discards: [Card.t()],
          stacks: {[Card.t()], [Card.t()], [Card.t()], [Card.t()]},
          winner: String.t() | nil
        }

  @type t :: %__MODULE__{
          revision: non_neg_integer(),
          expires_at: non_neg_integer(),
          timer: any(),
          state: state()
        }

  @spec new_game() :: state()
  def new_game() do
    numbers =
      Stream.cycle(1..12)
      |> Stream.take(144)
      |> Enum.map(&%Card{type: :number, value: &1})

    wilds =
      Stream.cycle([%Card{type: :skipbo, value: nil}])
      |> Enum.take(18)

    deck = (numbers ++ wilds) |> Enum.shuffle()

    %{
      deck: deck,
      players: %{},
      player_order: [],
      current_player: nil,
      started: false,
      room_id: nil,
      host_id: nil,
      discards: [],
      stacks: {[], [], [], []},
      winner: nil
    }
  end

  @spec start(state) :: state()
  def start(state) do
    {deck, players} =
      (state[:players] || %{})
      |> Map.values()
      |> Enum.reduce({state.deck, %{}}, fn %{id: id}, {deck, players} ->
        {stock, deck} = Enum.split(deck, 25)
        {hand, deck} = Enum.split(deck, 5)

        {deck,
         Map.put(players, id, %Player{
           id: id,
           hand: hand,
           stock: stock,
           discards: {[], [], [], []}
         })}
      end)

    player_order = Map.keys(players) |> Enum.shuffle()

    %{
      state
      | started: true,
        deck: deck,
        players: players,
        player_order: player_order,
        current_player: hd(player_order)
    }
  end

  @spec add_player(state()) :: {state(), String.t()}
  def add_player(state) do
    player = Player.new()
    # If this is the first player we can assume they are the host
    state = if state.players == %{}, do: Map.put(state, :host_id, player.id), else: state
    state = %{state | players: Map.put(state.players, player.id, player)}
    {state, player.id}
  end

  @spec remove_player(state(), String.t()) :: state()
  def remove_player(state, player_id) do
    %{state | players: Map.delete(state.players, player_id)}
  end

  @spec reshuffle_discards(state()) :: state()
  def reshuffle_discards(state) do
    new_deck =
      state.discards
      |> Enum.map(fn c -> if(c.type == :skipbo, do: %{c | value: nil}, else: c) end)
      |> Enum.shuffle()

    %{state | deck: state.deck ++ new_deck, discards: []}
  end

  @spec next_turn(state()) :: state()
  def next_turn(state) do
    current_index = Enum.find_index(state.player_order, &(&1 == state.current_player))
    next = Enum.at(state.player_order, rem(current_index + 1, length(state.player_order)))
    {player, state} = Player.redraw(state.players[next], state)

    %{state | players: Map.put(state.players, next, player), current_player: next}
  end
end
