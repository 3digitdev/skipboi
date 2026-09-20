defmodule Skipboi.Card do
  @enforce_keys [:value, :color, :type]
  defstruct [:value, :color, type: :number]

  @type t :: %__MODULE__{
          value: pos_integer() | nil,
          color: :red | :green | :blue | :yellow,
          type: :number | :skipbo
        }

  def new_game(state) do
    numbers =
      Stream.cycle(1..12)
      |> Stream.take(144)
      |> Enum.map(
        &%__MODULE__{
          type: :number,
          value: &1,
          color:
            case &1 do
              v when v < 5 -> :blue
              v when v < 9 -> :green
              v when v < 13 -> :red
            end
        }
      )

    wilds =
      Stream.cycle([%__MODULE__{type: :skipbo, value: nil, color: :yellow}])
      |> Stream.take(18)

    deck = (numbers ++ wilds) |> Enum.shuffle()

    {deck, player_map} =
      Enum.reduce(state["players"] || [], {deck, %{}}, fn player, {deck, stacks} ->
        {stack, deck} = Enum.split(deck, 25)
        {hand, deck} = Enum.split(deck, 5)
        {deck, Map.put(stacks, player, %{hand: hand, stack: stack})}
      end)
  end
end
