defmodule ExampleScenario do
  use Loadex.Scenario

  setup do
    1..50000
  end

  scenario index do
    IO.inspect(node(), label: "I'm running #{index} on node")

    for i <- 1..1_000_000 do
      task = Task.async(fn -> IO.puts("My number is #{index}!") end)
      :timer.sleep(1000)
      Task.await(task)
    end
  end

  teardown index do
    IO.puts("Bye from #{index}!")
  end
end
