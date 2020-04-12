defmodule Loadex.Runner do
  alias Loadex.Scenario.Spec
  alias ExHashRing.HashRing

  @backend Loadex.Runner.Default

  def child_spec(arg) do
    apply(@backend, :child_spec, [arg])
  end

  def start_link(arg) do
    apply(@backend, :start_link, [arg])
  end

  def run(mod, restart, rate) do
    {:ok, ring} = get_nodes_ring()
    current_node = node()
    restart_strategy = if restart, do: :transient, else: :temporary

    specs = apply(mod, :__setup__, [])

    IO.puts("#{mod} will be run #{length(specs)} times.")

    for spec <- specs do
      case which_node?(ring, Spec.id(spec)) do
        ^current_node ->
          apply(@backend, :run, [spec, restart_strategy, mod, rate])

        another_node ->
          :rpc.cast(another_node, @backend, :run, [spec, restart_strategy, mod, rate])
      end
    end

    :ok
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
