defmodule Webseed.Worker do
  use GenServer
  require Logger

  @moduledoc """
    This module handles the worker logics, which deals with the messages that are sent to the  
    server seeds. 
  """

  # -------------------
  #   GenServer calls
  # -------------------

  def start_link(state \\ %{}) do
    GenServer.start_link(__MODULE__, state)
  end

  # -----------------------
  #   GenServer functions
  # -----------------------

  def init(state) do
    Process.flag(:trap_exit, true)
    Process.send_after(self(), :connect, 1)
    {:ok, state}
  end

  def handle_info(:connect, state) do
    {:noreply, state, {:continue, :cycle}}
  end

  def handle_continue(:cycle, state) do
    Logger.info("=== Awaiting to seed ===")
    {:noreply, state, {:continue, :cycle}}
  end
end
