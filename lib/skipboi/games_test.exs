defmodule Skipboi.GamesTest do
  use ExUnit.Case, async: true

  alias Skipboi.Games

  setup do
    id = Games.create()
    on_exit(fn -> Games.finish(id) end)
    %{id: id}
  end

  test "broadcasts JSON state and retains it for late joiners", %{id: id} do
    Games.subscribe(id)

    assert {:ok, %{revision: 1, state: %{"cards" => [1, 2]}}} =
             Games.publish(id, 0, ~s({"cards":[1,2]}))

    assert_receive {:game_state, %{revision: 1}}
    assert {:ok, %{state: %{"cards" => [1, 2]}}} = Games.get(id)
  end

  test "rejects stale writes and invalid envelopes without changing state", %{id: id} do
    assert {:ok, _} = Games.publish(id, 0, ~s({"score":1}))
    assert {:error, :conflict} = Games.publish(id, 0, ~s({"score":2}))

    for invalid <- ["null", "[]", "{", String.duplicate("x", 65_537)] do
      assert {:error, :invalid_state} = Games.publish(id, 1, invalid)
    end

    assert {:ok, %{revision: 1, state: %{"score" => 1}}} = Games.get(id)
  end

  test "isolates rooms and deletes ended state", %{id: id} do
    other = Games.create()
    on_exit(fn -> Games.finish(other) end)
    Games.subscribe(id)
    Games.publish(other, 0, ~s({"score":5}))
    refute_receive {:game_state, _}
    Games.finish(id)
    assert_receive :game_ended
    assert {:error, :not_found} = Games.get(id)
    assert {:error, :not_found} = Games.publish(id, 0, "{}")
    assert {:ok, _} = Games.get(other)
  end

  test "expiry deletes state and tells subscribers", %{id: id} do
    Games.subscribe(id)
    send(Games, {:expire, id})
    assert {:error, :not_found} = Games.get(id)
    assert_receive :game_ended
  end
end
