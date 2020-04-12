defmodule ExampleScenario do
  use Loadex.Scenario

  setup do
    1..10000
  end

  scenario index do
    IO.inspect(node(), label: "I'm running #{index} on node")

    task = Task.async(fn -> IO.puts("My number is #{index}!") end)

    (index * 1000)..(index * 10000) |> Enum.random() |> :timer.sleep()

    Task.await(task)
  end

  teardown index do
    IO.puts("Bye from #{index}!")
  end
end
