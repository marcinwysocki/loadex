defmodule Loadex.Runner.Supervisor do
  @moduledoc false
  use DynamicSupervisor

  def restart do
    DynamicSupervisor.stop(__MODULE__)
  end

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one, max_restarts: 100_000, max_seconds: 5)
  end
end
