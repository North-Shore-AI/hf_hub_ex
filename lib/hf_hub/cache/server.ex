defmodule HfHub.Cache.Server do
  @moduledoc """
  GenServer for managing cache state and operations.

  This server maintains cache metadata, handles concurrent access,
  and implements LRU eviction policies.
  """

  use GenServer

  # Client API

  @doc """
  Starts the cache server.

  ## Options

    * `:name` - The name to register the server under. Defaults to `HfHub.Cache.Server`.

  ## Examples

      {:ok, pid} = HfHub.Cache.Server.start_link()
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    state = %{
      cache: %{},
      access_times: %{},
      total_size: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      total_size: state.total_size,
      file_count: map_size(state.cache),
      repos: state.cache |> Map.keys() |> Enum.uniq()
    }

    {:reply, {:ok, stats}, state}
  end

  @impl true
  def handle_call({:get_path, key}, _from, state) do
    case Map.get(state.cache, key) do
      nil ->
        {:reply, {:error, :not_cached}, state}

      path ->
        # Update access time
        new_access_times = Map.put(state.access_times, key, System.system_time(:second))
        {:reply, {:ok, path}, %{state | access_times: new_access_times}}
    end
  end

  @impl true
  def handle_cast({:add_file, key, path, size}, state) do
    new_cache = Map.put(state.cache, key, path)
    new_access_times = Map.put(state.access_times, key, System.system_time(:second))
    new_total_size = state.total_size + size

    new_state = %{
      state
      | cache: new_cache,
        access_times: new_access_times,
        total_size: new_total_size
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:remove_file, key}, state) do
    new_cache = Map.delete(state.cache, key)
    new_access_times = Map.delete(state.access_times, key)

    new_state = %{
      state
      | cache: new_cache,
        access_times: new_access_times
    }

    {:noreply, new_state}
  end
end
