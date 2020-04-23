defmodule ExampleScenario do
  use Loadex.Scenario

  setup do
    1..100
  end

  scenario index do
    IO.inspect(node(), label: "I'm running #{index} on node")

    loop_after 500, 10, :hibernate, iteration do
      task =
        Task.start(fn ->
          IO.puts("My number is #{index}, iteration #{iteration}!")
        end)
    end
  end

  teardown index do
    IO.puts("Bye from #{index}!")
  end
end
