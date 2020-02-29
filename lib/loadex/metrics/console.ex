defmodule Loadex.Metrics.Console do
  use GenServer

  def timing(key, time) do
    GenServer.cast(__MODULE__, {:timing, key, time})
  end

  def incr(key) do
    GenServer.cast(__MODULE__, {:incr, key})
  end

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_cast({:timing, key, time}, state) do
    IO.puts("timers.#{key}|#{time / 1000}ms")
    {:noreply, state}
  end

  def handle_cast({:incr, key}, state) do
    new_state = Map.put(state, "counters.#{key}", Map.get(state, key, 0) + 1)

    IO.puts("counters.#{key}|#{Map.get(new_state, "counters.#{key}")}")

    {:noreply, new_state}
  end
end
