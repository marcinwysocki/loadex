defmodule ExampleScenario do
  use Loadex.Scenario

  setup do
    1..100
  end

  scenario index do
    IO.inspect(node(), label: "I'm running #{index} on node")

    task = Task.async(fn -> IO.puts("My number is #{index}!") end)

    (index * 1)..(index * 100) |> Enum.random() |> :timer.sleep()

    Task.await(task)
  end

  teardown index do
    IO.puts("Bye from #{index}!")
  end
end
