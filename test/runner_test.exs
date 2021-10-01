defmodule Loadex.Test.RunnerTest do
  use ExUnit.Case

  alias Loadex.Runner

  setup_all do
    ControlCenter.start_link()

    :ok
  end

  setup do
    ControlCenter.reset()

    :ok
  end

  describe "run/3" do
    test "calls setup" do
      assert :ok = Runner.run(FakeScenario, false, 100)

      assert :setup in ControlCenter.get_actions()
    end

    test "restarts the worker" do
      ControlCenter.add_command(fn _ ->
        :timer.sleep(100)
        raise "Oh no!"
      end)

      assert :ok = Runner.run(FakeScenario, true, 100)

      :timer.sleep(200)
      Loadex.stop_all()

      assert ControlCenter.get_actions()
             |> Enum.filter(fn
               {:scenario, _} -> true
               _ -> false
             end)
             |> length()
             |> Kernel.>(5)
    end
  end
end
