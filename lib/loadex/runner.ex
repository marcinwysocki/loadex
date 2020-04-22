defmodule Loadex.Runner do
  alias Loadex.Scenario.Spec
  alias ExHashRing.HashRing

  @backend Loadex.Runner.Default

  def run(mod, restart, rate) do
    {:ok, ring} = get_nodes_ring()
    restart_strategy = if restart, do: :transient, else: :temporary

    specs = apply(mod, :__setup__, [])

    specs
    |> Stream.chunk_every(rate)
    |> Stream.zip(Stream.interval(1000))
    |> Stream.map(fn {specs, _} ->
      for spec <- specs do
        :rpc.cast(which_node?(ring, Spec.id(spec)), @backend, :run, [
          spec,
          restart_strategy,
          mod
        ])
      end
    end)
    |> Stream.run()
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
