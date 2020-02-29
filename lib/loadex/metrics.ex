defmodule Loadex.Metrics do
  @backend Loadex.Metrics.Noop

  def child_spec(opts) do
    %{
      id: @backend,
      start: {@backend, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end

  def with_timer(key, fun, args \\ []) do
    {time, result} = :timer.tc(fn -> apply(fun, args) end)

    apply(@backend, :timing, [key, time])

    result
  end

  def incr(key), do: apply(@backend, :incr, [key])

  def start_link(arg) do
    apply(@backend, :start_link, [arg])
  end
end
