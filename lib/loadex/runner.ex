defmodule Loadex.Runner do
  alias Loadex.Scenario.Spec
  alias ExHashRing.HashRing

  use GenServer

  def run(mod, restart, rate) do
    {:ok, ring} = get_nodes_ring()
    current_node = node()
    restart_strategy = if restart, do: :transient, else: :temporary

    specs = apply(mod, :__setup__, [])

    IO.puts("#{mod} will be run #{length(specs)} times.")

    for spec <- specs do
      case which_node?(ring, Spec.id(spec)) do
        ^current_node ->
          GenServer.cast(__MODULE__, {:run_spec, spec, restart_strategy, mod, rate})

        another_node ->


          :rpc.cast(another_node, GenServer, :cast, [
            __MODULE__,
            {:run_spec, spec, restart_strategy, mod, rate}
          ])
      end
    end

    :ok
  end

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def handle_cast({:run_spec, spec, restart_strategy, mod, rate} = msg, state) do
    case Hammer.check_rate("#{mod}", 1000, rate) do
      {:allow, _count} ->
        DynamicSupervisor.start_child(Loadex.Runner.Supervisor, %{
          id: "#{mod}_#{Spec.id(spec)}",
          start: {__MODULE__, :do_start_scenario, [mod, spec]},
          restart: restart_strategy
        })

      {:deny, _limit} ->
        GenServer.cast(__MODULE__, msg)
    end

    {:noreply, state}
  end

  def handle_cast(_, state) do
    {:noreply, state}
  end

  def do_start_scenario(mod, spec) do
    Loadex.Runner.Worker.start_link(mod, spec)
  end

  defp get_nodes_ring() do
    ring = HashRing.new()

    [node() | Node.list()]
    |> Enum.reduce({:ok, ring}, fn node, {:ok, prev_ring} ->
      HashRing.add_node(prev_ring, node)
    end)
  end

  def which_node?(ring, id) do
    HashRing.find_node(ring, id)
  end
end
