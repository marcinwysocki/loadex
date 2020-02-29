defmodule Loadex.Scenario.Spec do
  alias __MODULE__

  defstruct [:id, :seed, :scenario]

  def set_scenario(%Spec{} = spec, scenario), do: Map.put(spec, :scenario, scenario)
  def new(id, seed), do: %Spec{id: id, seed: seed}
  def id(%Spec{id: id}), do: id
  def seed(%Spec{seed: seed}), do: seed
end

defmodule Loadex.Scenario do
  alias Loadex.Metrics

  defmacro __using__(opts \\ []) do
    quote do
      import Loadex.Scenario, only: [setup: 1, scenario: 2, teardown: 2, verbose: 1]

      @scenario_key Atom.to_string(__MODULE__)
                    |> String.replace("Elixir.", "")
                    |> Macro.underscore()
      @scenario_name String.replace(@scenario_key, "_", " ")

      @defaults [verbose: true]
      @opts Keyword.merge(@defaults, unquote(opts))
    end
  end

  @doc """
  Required. Must return either a range or a list of %Loadex.Scenario.Spec{}
  """
  defmacro setup(do: block) do
    quote do
      def __setup__() do
        verbose("Starting scenario \"#{@scenario_name}\".")

        specifications =
          case unquote(block) do
            %Range{} = range ->
              range |> Enum.map(&Loadex.Scenario.Spec.new(&1, &1))

            [%Loadex.Scenario.Spec{} | _] = specs ->
              specs

            [] ->
              IO.puts("Empty setup.")
              []

            _ ->
              raise "setup must return a list of Loadex.Scenario.Spec structs"
          end

        verbose("#{length(specifications)} for \"#{@scenario_name}\"")

        Enum.map(specifications, fn spec ->
          Loadex.Scenario.Spec.set_scenario(spec, @scenario_key)
        end)
      end
    end
  end

  @doc """
  Required. Is given a seed from the spec as a parameter.
  """
  defmacro scenario(seed, do: block) do
    quote bind_quoted: [seed: Macro.escape(seed), block: escape_block(block)] do
      if Module.defines?(__MODULE__, {:__run__, 1}) do
        raise "there can only be a one scenario definition!"
      end

      def __run__(unquote(seed), id) do
        verbose("Starting scenario \"#{@scenario_name}\" for #{id}.")

        unquote(block)
      end
    end
  end

  @doc """
  Optional. Is given a seed from the spec as a parameter.
  """
  defmacro teardown(seed, do: block) do
    quote bind_quoted: [seed: Macro.escape(seed), block: escape_block(block)] do
      def __teardown__(unquote(seed)) do
        verbose("Tearing scenario \"#{@scenario_name}\" down for #{id}.")

        unquote(block)
      end
    end
  end

  defmacro verbose(msg) do
    if @opts[:verbose] do
      quote do
        IO.puts(unquote(msg))
      end
    end
  end

  defp escape_block(block) do
    Macro.escape(
      quote do
        unquote(block)
      end,
      unquote: true
    )
  end
end
