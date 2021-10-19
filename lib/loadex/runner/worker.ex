defmodule Loadex.Runner.Worker do
  @moduledoc false
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
    GenServer.start_link(__MODULE__, %{mod: mod, spec: spec, wait_for_queue: []})
  end

  def init(state) do
    Process.flag(:trap_exit, true)

    GenServer.cast(self(), :run)

    {:ok, state}
  end

  def terminate(_, %{mod: mod, spec: %Spec{seed: seed}}) do
    IO.inspect(label: "TERMINARTNARN")
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

  def handle_info({:wait_for, msg, timeout, fun}, %{wait_for_queue: []} = state) do
    state
    |> add_to_queue!({msg, timeout, fun})
    |> do_wait_for(msg, timeout, fun)
    |> noreply()
  end

  def handle_info({:wait_for, msg, timeout, fun}, state) do
    state
    |> add_to_queue!({msg, timeout, fun})
    |> noreply()
  end

  def handle_info({:stop, reason}, state), do: {:stop, reason, state}
  def handle_info(:timeout, state), do: {:stop, :normal, state}
  def handle_info({:EXIT, _, reason}, state), do: {:stop, reason, state}
  def handle_info(_, state), do: noreply(state)

  #### WAIT FOR

  defp do_wait_for(state, msg, timeout, fun) do
    receive do
      ^msg = awaited ->
        fun.(awaited)

        maybe_wait_for_more(state)

      other_message ->
        state
        |> maybe_handle_control_msgs(other_message)
        |> do_wait_for(msg, timeout, fun)
    after
      timeout -> nil
    end
  end

  defp maybe_handle_control_msgs(state, msg) do
    try do
      case handle_info(msg, state) do
        {:noreply, state} -> state
        {:stop, reason, _} -> Process.exit(self(), reason)
      end
    rescue
      _ -> state
    end
  end

  defp maybe_wait_for_more(state) do
    case pop_queue(state) do
      %{wait_for_queue: []} = state ->
        state

      %{wait_for_queue: [{msg, timeout, fun} | _]} = state ->
        do_wait_for(state, msg, timeout, fun)
    end
  end

  defp add_to_queue!(state, msg) do
    Map.update!(state, :wait_for_queue, fn list -> list ++ [msg] end)
  end

  defp pop_queue(%{wait_for_queue: [_ | tail]} = state), do: %{state | wait_for_queue: tail}

  #### HELPERS

  defp noreply(state), do: {:noreply, state}
end
