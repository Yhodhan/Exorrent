defmodule Peers.Worker do
  alias Peers.Messages

  use GenServer
  require Logger

  # -------------------
  #   GenServer calls
  # -------------------

  def start_link(state \\ %{}),
    do: GenServer.start_link(__MODULE__, state)

  def return_state(pid),
    do: GenServer.call(pid, :state)

  def download(pid) do
    GenServer.call(pid, :init_download)
  end

  # ----------------------
  #   GenServer functions
  # ----------------------

  def init(state),
    do: {:ok, state}

  def handle_call(:state, _from, state),
    do: {:reply, state, state}

  def handle_call(:init_download, _from, %{socket: socket} = state) do
    Logger.info("=== Init download from port: #{inspect(socket)}")
    interes_msg = Messages.interested()

    :gen_tcp.send(socket, interes_msg)

    with {:ok, <<len::32>>} <- :gen_tcp.recv(socket, 4, 15000),
         {:ok, id} <- :gen_tcp.recv(socket, len) do
      Logger.info("=== Response from peer: #{inspect(id)}")
      response = Messages.peer_response(id)

      {:reply, response, state}
    else
      _ ->
        Logger.error("=== Failed sending interest message")
        {:reply, :error, state}
    end
  end
end
