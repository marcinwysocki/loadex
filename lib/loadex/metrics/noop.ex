defmodule Loadex.Metrics.Noop do
  @moduledoc false
  def incr(_), do: :ok
  def timing(_, _), do: :ok
  def start_link(_), do: :ignore
end
