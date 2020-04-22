defmodule ExampleScenario do
  use Loadex.Scenario

  setup do
    1..50000
  end

  scenario index do
    IO.inspect(node(), label: "I'm running #{index} on node")

    loop_after 1000, 1_000_000, :hibernate, index do
      pid = self()

      task =
        Task.async(fn ->
          IO.puts("My number is #{index}!")

          for i <- 1..100 do
            send(pid, {:random_message, i})
          end
        end)

      Task.await(task)
    end
  end

  teardown index do
    IO.puts("Bye from #{index}!")
  end
end
