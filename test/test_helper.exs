ExUnit.start()

defmodule ControlCenter do
  use Agent

  @initial_state %{actions: [], commands: []}

  def start_link, do: Agent.start_link(fn -> @initial_state end, name: __MODULE__)

  def add_action(action),
    do: Agent.update(__MODULE__, fn state -> Map.update!(state, :actions, &[action | &1]) end)

  def get_actions, do: Agent.get(__MODULE__, & &1.actions)

  def add_command(command),
    do: Agent.update(__MODULE__, fn state -> Map.update!(state, :commands, &[command | &1]) end)

  def get_commands, do: Agent.get(__MODULE__, & &1.commands)

  def reset, do: Agent.update(__MODULE__, fn _ -> @initial_state end)
end

defmodule FakeScenario do
  use Loadex.Scenario

  Loadex.Scenario.setup do
    ControlCenter.add_action(:setup)

    1..5
  end

  scenario seed do
    ControlCenter.add_action({:scenario, seed})

    for cmd <- ControlCenter.get_commands() do
      cmd.(seed)
    end
  end

  teardown seed do
    ControlCenter.add_action({:teardown, seed})
  end
end
