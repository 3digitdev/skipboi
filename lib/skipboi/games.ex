defmodule Skipboi.Games do
  @moduledoc """
  Temporary, single-node JSON room relay. Clients own game rules; the relay only
  checks the JSON envelope, size and revision to prevent silent lost updates.
  Rooms disappear on restart, after 24 hours, or when explicitly ended.
  """
  use GenServer

  @ttl :timer.hours(24)
  @max_bytes 65_536

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def create, do: GenServer.call(__MODULE__, :create)
  def get(id), do: GenServer.call(__MODULE__, {:get, id})
  def subscribe(id), do: Phoenix.PubSub.subscribe(Skipboi.PubSub, topic(id))
  def publish(id, revision, json), do: GenServer.call(__MODULE__, {:publish, id, revision, json})
  def finish(id), do: GenServer.call(__MODULE__, {:finish, id})
  def topic(id), do: "game:#{id}"

  @impl GenServer
  def init(_opts), do: {:ok, %{}}

  @impl GenServer
  def handle_call(:create, _from, rooms) do
    id = UniqueNamesGenerator.generate([:adjectives, :colors, :animals], %{separator: "-"})

    if Map.has_key?(rooms, id) do
      {:reply, {:error, :conflict}, rooms}
    else
      # id = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
      expires_at = System.monotonic_time(:millisecond) + @ttl
      timer = Process.send_after(self(), {:expire, id}, @ttl)

      room = %{
        state: %{"score" => 0, "started" => false},
        revision: 0,
        expires_at: expires_at,
        timer: timer
      }

      {:reply, id, Map.put(rooms, id, room)}
    end
  end

  def handle_call({:get, id}, _from, rooms) do
    {room, rooms} = lookup(rooms, id)
    {:reply, snapshot(room), rooms}
  end

  def handle_call({:publish, id, revision, json}, _from, rooms) do
    {room, rooms} = lookup(rooms, id)
    IO.puts("Publishing #{inspect(json)}")

    with {:ok, current} <- snapshot(room),
         true <- revision == current.revision,
         {:ok, state} <- decode(json) do
      room = %{room | state: state, revision: revision + 1}
      {:ok, current} = snapshot(room)
      Phoenix.PubSub.broadcast(Skipboi.PubSub, topic(id), {:game_state, current})
      {:reply, {:ok, current}, Map.put(rooms, id, room)}
    else
      false -> {:reply, {:error, :conflict}, rooms}
      error -> {:reply, error, rooms}
    end
  end

  def handle_call({:finish, id}, _from, rooms) do
    {:reply, :ok, remove(rooms, id)}
  end

  @impl GenServer
  def handle_info({:expire, id}, rooms), do: {:noreply, remove(rooms, id)}

  defp lookup(rooms, id) do
    case Map.get(rooms, id) do
      nil ->
        {nil, rooms}

      room ->
        if room.expires_at <= System.monotonic_time(:millisecond),
          do: {nil, remove(rooms, id)},
          else: {room, rooms}
    end
  end

  defp snapshot(nil), do: {:error, :not_found}
  defp snapshot(room), do: {:ok, Map.take(room, [:state, :revision])}

  defp remove(rooms, id) do
    case Map.pop(rooms, id) do
      {nil, rooms} ->
        rooms

      {room, rooms} ->
        Process.cancel_timer(room.timer)
        Phoenix.PubSub.broadcast(Skipboi.PubSub, topic(id), :game_ended)
        rooms
    end
  end

  defp decode(json) when is_binary(json) and byte_size(json) <= @max_bytes do
    case Jason.decode(json) do
      {:ok, state} when is_map(state) -> {:ok, state}
      _ -> {:error, :invalid_state}
    end
  end

  defp decode(state) do
    {:ok, state}
  end
end
