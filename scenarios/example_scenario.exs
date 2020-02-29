defmodule ExampleScenario do
  use Loadex.Scenario

  setup do
    1..10
  end

  scenario index do
    task = Task.async(fn -> IO.puts("My number is #{index}!") end)

    (index * 100)..(index * 200) |> Enum.random() |> :timer.sleep()

    Task.await(task)
  end

  teardown _index do
    # whatever
  end
end
