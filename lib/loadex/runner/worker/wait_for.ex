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

  # this is a workaround for invoking end_scenario inside the wait_for block
  # TODO: a cleaner solution would be nice
  def handle_info({:stop, reason}, state), do: {:stop, reason, state}
  def handle_info(_, state), do: noreply(state)

  #### HELPERS

  defp noreply(state), do: {:noreply, state}
end
