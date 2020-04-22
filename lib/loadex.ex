defmodule Loadex do
  @moduledoc """
    Documentation for Loadex.
  """

  def join_cluster(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(fn node ->
      case Node.ping(node) do
        :pong ->
          {node, :ok}

        :pang ->
          {node, :node_down}
      end
    end)
  end

  def run(opts \\ [restart: false, scenario: nil, rate: 1_000_000]) do
    opts[:scenario]
    |> load_scenarios()
    |> IO.inspect(label: "Scenarios")
    |> Stream.map(&Loadex.Runner.run(&1, opts[:restart], opts[:rate]))
    |> Stream.run()

    {:ok, :scenarios_started}
  end

  def stop_all do
    Loadex.Runner.Supervisor.restart()
  end

  def load_scenarios(maybe_scenario) do
    on_all_nodes(:do_load_scenarios, [maybe_scenario]) |> elem(0) |> List.first()
  end

  def do_load_scenarios(nil) do
    File.ls!("./scenarios")
    |> Enum.map(fn file -> Code.compile_file(file, "./scenarios") end)
    |> Enum.map(fn [{mod, _}] -> mod end)
  end

  def do_load_scenarios(file) do
    [{mod, _}] = Code.compile_file(file)

    [mod]
  end

  defp on_all_nodes(action, args) do
    :rpc.multicall(__MODULE__, action, args)
  end
end
