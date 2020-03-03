defmodule Loadex do
  @moduledoc """
    Documentation for Loadex.
  """

  def run(opts \\ [restart: false, scenario: nil, rate: 1_000_000]) do
    opts[:scenario]
    |> load_scenarios()
    |> IO.inspect(label: "Scenarios")
    |> Stream.map(&Loadex.Runner.run(&1, opts[:restart], opts[:rate]))
    |> Stream.run()

    {:ok, :scenarios_started}
  end

  defp load_scenarios(nil) do
    File.ls!("./scenarios")
    |> Enum.map(fn file -> Code.compile_file(file, "./scenarios") end)
    |> Enum.map(fn [{mod, _}] -> mod end)
  end

  defp load_scenarios(file) do
    [{mod, _}] = Code.compile_file(file)

    [mod]
  end
end
