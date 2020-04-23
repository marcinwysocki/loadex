defmodule Loadex.Runner.Worker do
  alias Loadex.Scenario.Spec

  use GenServer

  def loop(left, fun, opts \\ []) do
    send(self(), {:loop, left, 0, opts, fun})
  end

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
    apply(mod, :__run__, [seed, id])

    {:noreply, state}
  end

  def handle_cast(_, state), do: {:noreply, state}

  def handle_info({:loop, left, done, opts, fun}, state) do
    apply(fun, [done + 1])

    case left do
      1 ->
        :ok

      _ ->
        Process.send_after(
          self(),
          {:loop, left - 1, done + 1, opts, fun},
          Keyword.get(opts, :sleep, 1)
        )
    end

    if opts[:hibernate] do
      {:noreply, state, :hibernate}
    else
      {:noreply, state}
    end
  end

  def handle_info({:EXIT, _, reason}, state), do: {:stop, reason, state}
  def handle_info(_, state), do: {:noreply, state}
end
