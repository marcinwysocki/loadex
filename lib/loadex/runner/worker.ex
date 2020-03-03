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

  def handle_cast(:run, %{mod: mod, spec: %Spec{id: id, seed: seed, scenario: scenario}} = state) do
    {status, result} =
      Metrics.with_timer(
        scenario,
        fn ->
          try do
            res = apply(mod, :__run__, [seed, id])
            {:ok, res}
          catch
            :exit, reason ->
              {:error, reason}

            err ->
              {:error, err}
          end
        end
      )

    case status do
      :ok ->
        Metrics.incr("#{scenario}.success")
        {:stop, :normal, state}

      :error ->
        Metrics.incr("#{scenario}.error")
        {:stop, result, state}
    end
  end

  def handle_info({:EXIT, _, reason}, state) when reason in [:normal, :shutdown],
    do: {:stop, reason, state}

  def handle_info({:EXIT, _, reason}, %{spec: %Spec{scenario: scenario}} = state) do
    Metrics.incr("#{scenario}.error")

    {:stop, reason, state}
  end

  def handle_info(_, state), do: {:noreply, state}
end
