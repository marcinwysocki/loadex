defmodule Loadex.Scenario.Helpers do
  def flush_messages do
    receive do
      _ -> flush_messages()
    after
      0 -> :ok
    end
  end
end
