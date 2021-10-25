defmodule ExampleScenario do
  use Loadex.Scenario

  setup do
    1..10
  end

  scenario index do
    IO.inspect(node(), label: "I'm running #{index} on node")
    self_pid = self()

    # create an async loop, with 10 repetitions every 500 ms
    loop_after 500, 10, iteration do

      # we'll simulate messages incoming from external processes
      task =
        Task.start(fn ->
          IO.puts("My number is #{index}, iteration #{iteration}!")
          :timer.send_after(iteration * 10, self_pid, :hello)
          :timer.send_after(iteration * 20, self_pid, :bye)
        end)

      # to wait for a message while _blocking_ the process, use receive
      receive do
        :hello ->
          IO.puts "Hello from loop in #{index}, iteration #{iteration}!"
      end

      receive do
        :bye ->
          IO.puts "Bye from loop in #{index}, iteration #{iteration}!"
      end

      if index == iteration do
          send(self(), {:msg, :bye_bye})
        end
    end

    # to wait for messages without blocking the process, use wait_for
    wait_for {:msg, :bye_bye} do
      IO.puts "Bye!"

      end_scenario()
    end
  end

  teardown index do
    IO.puts("Bye from #{index}!")
  end
end
