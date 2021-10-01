defmodule Loadex.Test.WorkerTest do
  use ExUnit.Case

  alias Loadex.Runner.Worker
  alias Loadex.Scenario.Spec

  setup_all do
    ControlCenter.start_link()

    :ok
  end

  setup do
    ControlCenter.reset()

    :ok
  end

  describe "worker process" do
    test "starts" do
      spec = Spec.new(1, 1)

      assert {:ok, pid} = Worker.start_link(FakeScenario, spec)
      assert is_pid(pid)
    end

    test "is linked to the caller" do
      Process.flag(:trap_exit, true)

      spec = Spec.new(1, 1)
      {:ok, pid} = Worker.start_link(FakeScenario, spec)
      Process.exit(pid, :die)

      assert_receive {:EXIT, ^pid, :die}
    end

    test "runs the scenario with a seed" do
      seed = %{"some" => "values"}
      spec = Spec.new(1, seed)

      {:ok, _} = Worker.start_link(FakeScenario, spec)

      assert {:scenario, seed} in ControlCenter.get_actions()
    end

    test "calls teardown with a seed when it stops" do
      Process.flag(:trap_exit, true)

      seed = %{"some" => "values"}
      spec = Spec.new(1, seed)

      {:ok, pid} = Worker.start_link(FakeScenario, spec)
      Process.exit(pid, :shutdown)

      assert_receive {:EXIT, ^pid, :shutdown}
      assert {:teardown, seed} in ControlCenter.get_actions()
    end

    test "exits and calls teardown when scenario's code crashes" do
      Process.flag(:trap_exit, true)

      ControlCenter.add_command(fn _ -> raise "Oh No!" end)
      spec = Spec.new(1, 1)
      {:ok, pid} = Worker.start_link(FakeScenario, spec)

      assert_receive {:EXIT, ^pid, {%RuntimeError{}, _}}
      assert {:teardown, 1} in ControlCenter.get_actions()
    end

    test "exits and calls teardown when a process linked to the scenario crashes" do
      Process.flag(:trap_exit, true)

      ControlCenter.add_command(fn _ -> Task.start_link(fn -> raise "Oh No!" end) end)
      spec = Spec.new(1, 1)
      {:ok, pid} = Worker.start_link(FakeScenario, spec)

      assert_receive {:EXIT, ^pid, {%RuntimeError{}, _}}
      assert {:teardown, 1} in ControlCenter.get_actions()
    end
  end

  describe "stop/1" do
    test "stops the process" do
      Process.flag(:trap_exit, true)

      ControlCenter.add_command(fn _ -> Worker.stop(:time_has_come) end)
      spec = Spec.new(1, 1)
      {:ok, pid} = Worker.start_link(FakeScenario, spec)

      assert_receive {:EXIT, ^pid, :time_has_come}
    end

    test "calls teardown" do
      Process.flag(:trap_exit, true)

      ControlCenter.add_command(fn _ -> Worker.stop(:time_has_come) end)
      spec = Spec.new(1, 1)
      {:ok, pid} = Worker.start_link(FakeScenario, spec)

      assert_receive {:EXIT, ^pid, :time_has_come}
      assert {:teardown, 1} in ControlCenter.get_actions()
    end
  end

  describe "loop/3" do
    test "doesn't block the process" do
      test_pid = self()

      ControlCenter.add_command(fn _ -> Worker.loop(10, fn _ -> :noop end, sleep: 1000) end)
      ControlCenter.add_command(fn _ -> send(test_pid, :after_loop) end)
      spec = Spec.new(1, 1)
      {:ok, pid} = Worker.start_link(FakeScenario, spec)

      assert_receive :after_loop
    end

    test "calls the function with an iteration number given number of times" do
      test_pid = self()

      ControlCenter.add_command(fn _ ->
        Worker.loop(5, fn iteration -> send(test_pid, {:loop, iteration}) end)
      end)

      spec = Spec.new(1, 1)
      {:ok, pid} = Worker.start_link(FakeScenario, spec)

      for number <- 1..5 do
        assert_receive {:loop, number}
      end

      refute_receive {:loop, 6}
    end

    test "calls the function with an interval set as a sleep opt" do
      test_pid = self()

      ControlCenter.add_command(fn _ ->
        Worker.loop(2, fn iteration -> send(test_pid, {:loop, iteration}) end, sleep: 200)
      end)

      spec = Spec.new(1, 1)
      {:ok, pid} = Worker.start_link(FakeScenario, spec)

      assert_receive {:loop, 1}

      :timer.sleep(50)
      refute_received {:loop, 2}

      :timer.sleep(50)
      refute_received {:loop, 2}

      :timer.sleep(110)
      assert_received {:loop, 2}
    end
  end
end
