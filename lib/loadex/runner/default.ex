defmodule Loadex.Runner.Default do
  use GenServer

  alias Loadex.Scenario.Spec

  def run(spec, restart_strategy, mod, rate) do
    GenServer.cast(__MODULE__, {:run_spec, spec, restart_strategy, mod, rate, 0})
  end

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def handle_cast({:run_spec, spec, restart_strategy, mod, rate, retries} = msg, state) do
    case Hammer.check_rate("#{mod}", 1000, rate) do
      {:allow, _count} ->
        DynamicSupervisor.start_child(Loadex.Runner.Supervisor, %{
          id: "#{mod}_#{Spec.id(spec)}",
          start: {__MODULE__, :do_start_scenario, [mod, spec]},
          restart: restart_strategy
        })

      {:deny, _limit} ->
        new_retries = retries + 1
        :timer.apply_after(5000 * new_retries, GenServer, :cast, [__MODULE__, msg])
    end

    {:noreply, state}
  end

  def handle_cast(_, state) do
    {:noreply, state}
  end

  def do_start_scenario(mod, spec) do
    Loadex.Runner.Worker.start_link(mod, spec)
  end
end
