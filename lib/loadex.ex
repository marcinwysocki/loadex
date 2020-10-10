defmodule Loadex do
  @moduledoc """
  A simple distributed load test runner.

  `Loadex` was created with two things in mind - genarating huge loads in a controlled manner, while being able to fully customize the test's flow.
  These goals are achieved by using plain Elixir to create *scenarios* and then laveraging Elixir's massive concurrency capabilities to run them on one or multiple machines.

  ## Example:

      defmodule ExampleScenario do
        use Loadex.Scenario

        setup do
          1..100
        end

        scenario index do
          loop_after 500, 10, iteration do
            IO.puts("My number is \#{index}, iteration \#{iteration}!")
          end
        end

        teardown index do
          IO.puts("Bye from \#{index}!")
        end
      end

  For detailed instructions on how to create a scenario please refer to `Loadex.Scenario`.
  """

  @doc """
  Runs scenarios.

  Running a scenario means executing its `setup` callback and passing its results to the `scenario` implementation.
  For more detailed information on how to create scenarios please refer to `Loadex.Scenario`.

  When running in a distributed environment (see `join_cluster/1`), **the `setup` callback will be executed on a node `run/1` is called on** and its results will
  be distributed along the cluster.

  By default scenarios are loaded from `./scenarios` directory and executed all at the same time.
  A single scenario can be specified by passing a `scenario` option.

  Scenarios can be restarted after crashing or quitting by passing `restart: true` option.

  Rate (per second), at which scenarios are started can be adjusted by passing a `rate` option. **Note:** this doesn't affect *restart* rate.


  ## Example:

      iex> Loadex.run(scenario: "./scenarios/example_scenario.exs", rate: 30, restart: true)
  """
  @spec run(opts :: [restart: boolean(), scenario: nil | binary(), rate: non_neg_integer()]) ::
          {:ok, :scenarios_started}
  def run(opts \\ [restart: false, scenario: nil, rate: 1000]) do
    opts[:scenario]
    |> load_scenarios()
    |> IO.inspect(label: "Scenarios")
    |> Stream.map(&Loadex.Runner.run(&1, opts[:restart], opts[:rate]))
    |> Stream.run()

    {:ok, :scenarios_started}
  end

  @doc """
  Adds `nodes` into the `Loadex` cluster.
  """
  @spec join_cluster(nodes :: [atom()]) :: [atom()]
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

  @doc """
  Stops all scenarios.
  """
  @spec stop_all :: :ok
  def stop_all do
    Loadex.Runner.Supervisor.restart()
  end

  defp load_scenarios(maybe_scenario) do
    on_all_nodes(Loadex.Scenario.Loader, :load, [maybe_scenario])
  end

  defp on_all_nodes(mod, action, args) do
    :rpc.multicall(mod, action, args) |> elem(0) |> List.first()
  end
end
