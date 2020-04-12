defmodule Loadex.Runner.Worker do
  alias Loadex.Metrics
  alias Loadex.Scenario.Spec

  use GenServer

  def start_link(mod, spec) do
    GenServer.start_link(__MODULE__, %{mod: mod, spec: spec})
  end

  def init(state) do
    Process.flag(:trap_exit, true)

    GenServer.cast(self(), :run)

    {:ok, state}
  end

  def terminate(_, %{mod: mod, spec: %Spec{seed: seed}}) do
    if Kernel.function_exported?(mod, :__teardown__, 1) do
      apply(mod, :__teardown__, [seed])
    end
  end

  def handle_cast(:run, %{mod: mod, spec: %Spec{id: id, seed: seed}} = state) do
    {:ok, pid} = Task.start_link(mod, :__run__, [seed, id])

    {:noreply, Map.put(state, :worker, pid)}
  end

  def handle_info({:EXIT, pid, _}, %{worker: pid} = state), do: {:stop, state}
  def handle_info({:EXIT, _, _}, state), do: {:noreply, state}
  def handle_info(_, state), do: {:noreply, state}
end
