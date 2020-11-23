defmodule Loadex.Scenario do
  @moduledoc """
  A set of macros used to create Loadex scenarios.

  ## What is a scenario?

  **TL;DR:** *Scenario* is basically a load test case.

  The common problem with load testing is that a synthtetic load doesn't really produce great results.
  Performance is measured, the application is deployed to production and then it crashes under much smaller load, than we generated using our favourite load testing tool.

  The reason is that synthetic load is, well, synthetic. While testing a single REST endpoint probably may not be a problem, more complex workflows can run into such issues quite easily.
  It makes a lot of sense, then, for our load tests to reflect the real world use cases of the application we're testing.
  This may include aquiring a token for authentication, creating a persistent connection using a required protocol, executing some specific handshake or initialization etc.

  It requires expressiveness usually associated with programming languages. Scenarios provide a way of describing complex workflows with Elixir code and libraries.
  They're then executed concurrently to generate substantial loads.

  ## Creating a scenario

  ### Setup

  Each `Loadex` scenario starts with a `setup/1` macro. It defines how many workers need to be started and what data should they receive as an optional *seed*.
  This can be done in one of two ways: either returning a `Range`:

      setup do
        1..10
      end

  ...or a `Stream` of `Loadex.Scenario.Spec` structs with an unique `id` and a `seed` for each scenario:
      setup do
        load_users_from_csv()
        |> Stream.map(fn %User{id: id} = user ->
          Loadex.Scenario.Spec.new(id, user)
        end)
      end

  For more information please refer to `setup/1`.

  ### Scenario

  This is where magic happens. Scenario's code is executed in a separate process for every element returned by the `setup`.
  This element, a _seed_, is given as a prameter to the `scenario/2` macro:

      defmodule ExampleScenario do
        setup do
          load_users_from_csv()
          |> Stream.map(fn %User{id: id} = user ->
            Loadex.Scenario.Spec.new(id, user)
          end)
        end

        scenario %User{login: login, password: password} do
          token = AuthClient.get_token(login, password)

          loop_after 2000, 10, _repetition do
            ExternalServiceClient.generate_some_load(token)
          end
        end
      end

  This simple scenario above loads a bunch of users from a CSV during the `setup` stage.
  Then each user concurrently aquires a token and finally starts making calls, every two seconds and ten in total, to the external service we want to test.

  Note that we're using the `loop_after/4` macro instead of `:timer.sleep/1` and `Enum.each/2` or a list comprehension.
  The reason for this is that our scenario is run in a process and iterating on a list (or `Range`) and `:timer.sleep/1` calls are blocking it.
  Meanwhile, `loop_after/4` is asynchronous to ensure the worker can receive and process messages.

  While it may not be an issue in your case, it is strongly advised to use built-in helpers to ensure all the performance benefits, that using Elixir and OTP gives us.
  Please refer to their documentation for more details.
  """
  defmodule Loader do
    @moduledoc false
    @default_path "./scenarios"
    def load(maybe_scenario) do
      do_load_scenarios(maybe_scenario)
    end

    defp do_load_scenarios(nil) do
      File.ls!(@default_path)
      |> Enum.map(&Code.compile_file(&1, @default_path))
      |> Enum.map(fn [{mod, _}] -> mod end)
    end

    defp do_load_scenarios(file) do
      [{mod, _}] = Code.compile_file(file)

      [mod]
    end
  end

  defmodule Spec do
    @moduledoc """
    TODO
    """
    alias __MODULE__

    defstruct [:id, :seed, :scenario]

    def set_scenario(%Spec{} = spec, scenario), do: Map.put(spec, :scenario, scenario)
    def new(id, seed), do: %Spec{id: id, seed: seed}
    def id(%Spec{id: id}), do: id
    def seed(%Spec{seed: seed}), do: seed
  end

  defmacro __using__(opts \\ []) do
    quote do
      import Loadex.Scenario,
        only: [
          setup: 1,
          scenario: 2,
          teardown: 2,
          verbose: 1,
          loop: 3,
          loop: 4,
          loop_after: 4,
          loop_after: 5,
          end_scenario: 0
        ]

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
              range |> Stream.map(&Loadex.Scenario.Spec.new(&1, &1))

            %Stream{} = specs ->
              specs

            _ ->
              raise "setup must return a Stream of Loadex.Scenario.Spec structs or a Range"
          end

        Stream.map(specifications, fn spec ->
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

  defmacro loop(how_many_times, hibernate_or_standby \\ :standby, match, do: block) do
    hibernate? =
      case hibernate_or_standby do
        :hibernate -> true
        :standby -> false
      end

    quote bind_quoted: [
            how_many_times: how_many_times,
            fun: do_loop(match, block),
            hibernate?: hibernate?
          ] do
      Loadex.Runner.Worker.loop(how_many_times, fun, hibernate: hibernate?)
    end
  end

  defmacro loop_after(time, how_many_times, hibernate_or_standby \\ :standby, match, do: block) do
    hibernate? =
      case hibernate_or_standby do
        :hibernate -> true
        :standby -> false
      end

    quote bind_quoted: [
            time: time,
            how_many_times: how_many_times,
            fun: do_loop(match, block),
            hibernate?: hibernate?
          ] do
      Loadex.Runner.Worker.loop(how_many_times, fun, sleep: time, hibernate: hibernate?)
    end
  end

  defp do_loop(match, block) do
    quote do
      fn unquote(match) ->
        unquote(block)
      end
    end
  end

  defmacro end_scenario do
    quote do
      Loadex.Runner.Worker.stop()
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
