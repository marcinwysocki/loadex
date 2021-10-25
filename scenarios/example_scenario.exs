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

      # we'll start a separate process for each iteration
      # and then send messages to the main scenario process
      # to simulate incoming messages
      task =
        Task.start(fn ->
          IO.puts("My number is #{index}, iteration #{iteration}!")
          :timer.send_after(iteration * 10, self_pid, :hello)
          :timer.send_after(iteration * 20, self_pid, :bye)
        end)

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

    wait_for {:msg, :bye_bye} do
      IO.puts "Bye!"

      end_scenario()
    end
  end

  teardown index do
    IO.puts("Bye from #{index}!")
  end
end
