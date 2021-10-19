defmodule ExampleScenario do
  use Loadex.Scenario

  setup do
    1..5
  end

  scenario index do
    IO.inspect(node(), label: "I'm running #{index} on node")

    loop_after 500, 100, :hibernate, iteration do
      task =
        Task.start(fn ->
          IO.puts("My number is #{index}, iteration #{iteration}!")
        end)

        if index == iteration do
          send(self(), {:msg, :bye_bye})
        end
    end

    wait_for {:msg, :bye_bye} do
      IO.puts "Bye!"

      end_scenario()
    end
  end

  teardown index do
    IO.puts("Bye from #{index}!")
  end
end
