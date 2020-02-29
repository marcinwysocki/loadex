defmodule Loadex.Metrics.Noop do
  def incr(_), do: :ok
  def timing(_, _), do: :ok
  def start_link(_), do: :ignore
end
