defmodule Loadex.Runner.Worker.WaitFor do
  @moduledoc false

  use GenServer

  def enqueue(pid, msg, timeout, fun) do
    GenServer.cast(pid, {:enqueue, {msg, timeout, fun}})
  end

  def send(pid, msg) do
    GenServer.cast(pid, {:msg, msg})
  end

  def start_link(queue \\ []) do
    GenServer.start_link(__MODULE__, queue)
  end

  def init(queue) do
    {:ok, queue}
  end

  def handle_cast({:enqueue, spec}, queue) do
    queue
    |> Kernel.++([spec])
    |> noreply()
  end

  def handle_cast({:msg, msg}, [{msg, _, fun} | tail]) do
    fun.(msg)

    noreply(tail)
  end

  def handle_cast(_, queue), do: noreply(queue)

  #### HELPERS

  defp noreply(state), do: {:noreply, state}
end
