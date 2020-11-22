defmodule Loadex.Runner.Default do
  @moduledoc false
  alias Loadex.Scenario.Spec

  def run(spec, restart_strategy, mod) do
    DynamicSupervisor.start_child(Loadex.Runner.Supervisor, %{
      id: "#{mod}_#{Spec.id(spec)}",
      start: {Loadex.Runner.Worker, :start_link, [mod, spec]},
      restart: restart_strategy
    })
  end
end
