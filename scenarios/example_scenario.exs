defmodule ExampleScenario do
  use Loadex.Scenario

  setup do
    1..10
  end

  scenario index do
    task = Task.async(fn -> IO.puts("My number is #{index}!") end)

    (index * 10000)..(index * 20000) |> Enum.random() |> :timer.sleep()

    Task.await(task)
  end

  teardown index do
    IO.puts("Bye from #{index}!")
  end
end
