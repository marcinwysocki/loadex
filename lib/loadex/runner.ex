defmodule Loadex.Runner do
  alias Loadex.Scenario.Spec

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 1000, max_seconds: 1)
  end

  def run(%{restart: restart}) do
    restart_strategy = if restart, do: :transient, else: :temporary

    load_scenarios()
    |> IO.inspect(label: "Scenarios")
    |> Stream.map(fn mod ->
      specs = apply(mod, :__setup__, [])

      IO.puts("#{mod} will be run #{length(specs)} times.")

      for spec <- specs do
        DynamicSupervisor.start_child(__MODULE__, %{
          id: "#{mod}_#{Spec.id(spec)}",
          start: {__MODULE__, :do_start_scenario, [mod, spec]},
          restart: restart_strategy
        })
      end
    end)
    |> Stream.run()

    {:ok, :scenarios_started}
  end

  def do_start_scenario(mod, spec) do
    Loadex.Worker.start_link(mod, spec)
  end

  defp load_scenarios do
    File.ls!("./scenarios")
    |> Enum.map(fn file -> Code.compile_file(file, "./scenarios") end)
    |> Enum.map(fn [{mod, _}] -> mod end)
  end
end
