defmodule Weebseed.Worker do
  use GenServer
  require Logger

  @moduledoc """
    This module handles the worker logics, which deals with the messages that are sent to the  
    server seeds. 
  """

  # -------------------
  #   GenServer calls
  # -------------------

  def start_link(state \\ %{}),
    do: GenServer.start_link(__MODULE__, state)

  # -----------------------
  #   GenServer functions
  # -----------------------

  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, state}
  end
end
