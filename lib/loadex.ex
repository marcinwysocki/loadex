defmodule Loadex do
  @moduledoc """
    Documentation for Loadex.
  """

  def run(opts \\ %{restart: false}) do
    Loadex.Runner.run(opts)
  end
end
