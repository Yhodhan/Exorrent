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

  #  def download(pid),
  #    do: GenServer.call(pid, :init_download)

  # ----------------------
  #   GenServer functions
  # ----------------------

  def init(state),
    do: {:ok, state}

  def handle_call(:state, _from, state),
    do: {:reply, state, state}

  def handle_info(:cycle, %{socket: socket, status: :idle} = state) do
    with {:ok, <<len::32>>} <- :gen_tcp.recv(socket, 4, 5000),
         {:ok, id, len} <- peer_message(len, socket),
         {:ok, new_state} <- process_message(id, len, state) do
      Process.send_after(self(), :cycle, 0)
      {:noreply, new_state}
    else
      :keep_alive ->
        Process.send_after(self(), :cycle, 0)
        {:noreply, state}

      {:error, :timeout} ->
        Process.send_after(self(), :cycle, 100)
        {:noreply, state}

      {:error, :closed} ->
        :gen_tcp.close(socket)
        {:stop, :normal, state}
    end
  end

  #  def handle_call(:init_download, _from, %{socket: socket} = state) do
  #    Logger.info("=== Init download from port: #{inspect(socket)}")
  #    interes_msg = Messages.interested()
  #
  #    :gen_tcp.send(socket, interes_msg)
  #
  #    with {:ok, <<len::32>>} <- :gen_tcp.recv(socket, 4, 15000),
  #         {:ok, id} <- :gen_tcp.recv(socket, len) do
  #      Logger.info("=== Response from peer: #{inspect(id)}")
  #      response = peer_response(id)
  #
  #      {:reply, response, state}
  #    else
  #      _ ->
  #        Logger.error("=== Failed sending interest message")
  #        {:reply, :error, state}
  #    end
  #  end

  # -------------------
  #  Private functions
  # -------------------
  def peer_message(<<0::32>>, _socket),
    do: :keep_alive

  def peer_message(<<len::32>>, socket) do
    with {:ok, id} <- :gen_tcp.recv(socket, 1) do
      {:ok, id, len - 1}
    end
  end

  # choke
  def process_message(0, _len, state),
    do: {:ok, %{state | choke: true}}

  # unchoke
  def process_message(1, _len, state),
    do: {:ok, %{state | choke: false, unchoked: true}}

  # interested
  def process_message(2, _len, state),
    do: {:ok, %{state | interested: true}}

  # not interested
  def process_message(3, _len, state),
    do: {:ok, %{state | interested: false}}

  # have
  def process_message(4, _len, state) do
  end
end
