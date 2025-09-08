defmodule Peers.Worker do
  use GenServer

  # -------------------
  #   GenServer calls
  # -------------------

  def start_link(state \\ %{}),
    do: GenServer.start_link(__MODULE__, state)

  def return_state(pid),
    do: GenServer.call(pid, :state)

  # ----------------------
  #   GenServer functions
  # ----------------------

  def init(state),
    do: {:ok, state}

  def handle_call(:state, _from, state),
    do: {:reply, state, state}
end
