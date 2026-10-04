defmodule Skipboi.Player do
  alias Skipboi.Card
  alias Skipboi.Game

  @enforce_keys [:id, :hand, :discards, :stock]
  defstruct [:id, :hand, :discards, :stock]

  @type t :: %__MODULE__{
          id: String.t(),
          hand: [Card.t()],
          discards: {[Card.t()], [Card.t()], [Card.t()], [Card.t()]},
          stock: [Card.t()]
        }

  @spec new() :: __MODULE__.t()
  def new() do
    %__MODULE__{
      id: UniqueNamesGenerator.generate([:adjectives, :names], %{style: :capital, separator: ""}),
      hand: [],
      discards: {[], [], [], []},
      stock: []
    }
  end

  @spec discard(__MODULE__.t(), non_neg_integer(), non_neg_integer()) :: __MODULE__.t()
  def discard(player, card_idx, discard_idx) do
    {card, new_hand} = List.pop_at(player.hand, card_idx)
    discard_pile = elem(player.discards, discard_idx)

    %{
      player
      | discards: put_elem(player.discards, discard_idx, [card | discard_pile]),
        hand: new_hand
    }
  end

  @spec redraw(__MODULE__.t(), Game.state()) :: {__MODULE__.t(), Game.state()}
  def redraw(player, state) do
    missing = 5 - length(player.hand)

    state =
      if length(state.deck) < missing do
        Game.reshuffle_discards(state)
      else
        state
      end

    {draw, deck} = Enum.split(state.deck, missing)
    player = %{player | hand: player.hand ++ draw}
    {player, %{state | deck: deck}}
  end

  @spec play_card(
          __MODULE__.t(),
          Game.state(),
          :hand | :stock | :discard,
          non_neg_integer(),
          non_neg_integer() | nil
        ) ::
          {atom(), {__MODULE__.t(), Game.state()}}
  def play_card(player, state, _src, idx, _card_idx) when idx > 3,
    do: {:bad_index, {player, state}}

  def play_card(player, state, :hand, _idx, nil), do: {:bad_index, {player, state}}

  def play_card(player, state, :hand, _idx, card_idx) when card_idx >= length(player.hand),
    do: {:bad_index, {player, state}}

  def play_card(player, state, :stock, _idx, _cidx) when player.stock == [],
    do: {:player_already_won, {player, state}}

  def play_card(player, state, :discard, _idx, card_idx) when card_idx > 3,
    do: {:bad_index, {player, state}}

  def play_card(player, state, :discard, _idx, card_idx)
      when elem(player.discards, card_idx) == [], do: {:discard_empty, {state, player}}

  def play_card(player, state, source, stack_idx, card_idx) do
    stack = elem(state.stacks, stack_idx)
    top_card = List.last(stack)

    {card, player_played} =
      case source do
        :hand ->
          {card, new_hand} = List.pop_at(player.hand, card_idx)
          {card, %{player | hand: new_hand}}

        :stock ->
          {card, new_stock} = List.pop_at(player.stock, 0)
          {card, %{player | stock: new_stock}}

        :discard ->
          {card, new_discard} =
            player.discards
            |> elem(card_idx)
            |> List.pop_at(0)

          {card, %{player | discards: put_elem(player.discards, card_idx, new_discard)}}
      end

    cond do
      is_nil(top_card) and card.type == :number and card.value != 1 ->
        dbg("not playing 1 on empty stack")
        {:invalid_card, {player, state}}

      not is_nil(top_card) and top_card.value == 12 ->
        {:full_stack, {player, state}}

      not is_nil(top_card) and card.type == :number and card.value != top_card.value + 1 ->
        dbg("trying to play #{card.value} on #{top_card.value + 1}")
        {:invalid_card, {player, state}}

      true ->
        # Assign a proper value to the wildcards
        card =
          if card.type == :skipbo do
            Map.put(card, :value, if(is_nil(top_card), do: 1, else: top_card.value + 1))
          else
            card
          end

        {stack, old_stack} =
          if card.value == 12, do: {[], [card | stack]}, else: {stack ++ [card], nil}

        # automatically redraw if we used the last card
        {player_played, state} =
          if player_played.hand == [] do
            redraw(player_played, state)
          else
            {player_played, state}
          end

        {:ok,
         {player_played,
          %{
            state
            | stacks: put_elem(state.stacks, stack_idx, stack),
              discards: state.discards ++ (old_stack || []),
              winner: if(player_played.stock == [], do: player_played.id)
          }}}
    end
  end
end
