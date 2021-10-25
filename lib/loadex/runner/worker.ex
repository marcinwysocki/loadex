defmodule Loadex.Runner.Worker do
  @moduledoc false
  alias Loadex.Runner.Worker.WaitFor
  alias Loadex.Scenario.Spec

  use GenServer

  def loop(left, fun, opts \\ []) do
    send(self(), {:loop, left, 0, opts, fun})
  end

  def wait_for(msg, timeout \\ 5000, fun) do
    send(self(), {:wait_for, msg, timeout, fun})
  end

  def stop(reason \\ :normal) do
    send(self(), {:stop, reason})
  end

  def start_link(mod, spec) do
    GenServer.start_link(__MODULE__, %{mod: mod, spec: spec})
  end

  def init(state) do
    Process.flag(:trap_exit, true)

    {:ok, handler} = WaitFor.start_link()
    GenServer.cast(self(), :run)

    {:ok, Map.put_new(state, :wait_for_handler, handler)}
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
        {:noreply, state, 5000}

      _ ->
        Process.send_after(
          self(),
          {:loop, left - 1, done + 1, opts, fun},
          Keyword.get(opts, :sleep, 1)
        )

        if opts[:hibernate] do
          {:noreply, state, :hibernate}
        else
          {:noreply, state}
        end
    end
  end

  def handle_info({:wait_for, msg, timeout, fun}, %{wait_for_handler: pid} = state) do
    WaitFor.enqueue(pid, msg, timeout, fun)

    noreply(state)
  end

  def handle_info({:stop, reason}, state), do: {:stop, reason, state}
  def handle_info(:timeout, state), do: {:stop, :normal, state}
  def handle_info({:EXIT, _, reason}, state), do: {:stop, reason, state}

  def handle_info(msg, %{wait_for_handler: pid} = state) do
    WaitFor.send(pid, msg)
    noreply(state)
  end

  #### HELPERS

  defp noreply(state), do: {:noreply, state}
end
