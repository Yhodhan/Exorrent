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

  def init_cycle(pid),
    do: send(pid, :cycle)

  # ----------------------
  #   GenServer functions
  # ----------------------

  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, state}
  end

  def handle_info(
        :cycle,
        %{socket: socket, status: :idle, choke: true, interested: false} = state
      ) do
    Logger.info("=== Send interest message")
    interes = Messages.interested()

    :gen_tcp.send(socket, interes)
    Process.send_after(self(), :cycle, 1)

    {:noreply, %{state | interested: true}}
  end

  def handle_info(:cycle, %{socket: socket, status: :idle, interested: true} = state) do
    Logger.info("=== Worker Cycle")

    with {:ok, <<len::32>>} <- :gen_tcp.recv(socket, 4, 100),
         {:ok, id, len} <- peer_message(len, socket),
         {:ok, new_state} <- process_message(id, len, state) do
      Process.send_after(self(), :cycle, 10)
      {:noreply, new_state}
    else
      error ->
        handle_error(error, state, socket)
    end
  end

  def handle_info(msg, state) do
    Logger.warning("=== Unhandled message in #{inspect(self())}: #{inspect(msg)}")
    {:noreply, state}
  end

  # -------------------
  #  Private functions
  # -------------------
  def peer_message(0, _socket),
    do: :keep_alive

  def peer_message(len, socket) do
    # Logger.info("bytes len of message #{byte_size(len)}")
    with {:ok, <<id::8>>} <- :gen_tcp.recv(socket, 1, 100) do
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
  def process_message(4, len, %{socket: socket} = state) do
    with {:ok, piece_index} <- :gen_tcp.recv(socket, len) do
      Logger.info("=== Piece obtained: #{inspect(piece_index)}")
      {:ok, state}
    end
  end

  # bitfield
  def process_message(5, len, %{socket: socket} = state) do
    with {:ok, bitfield} <- :gen_tcp.recv(socket, len) do
      Logger.info("=== Bitfield obtained: #{inspect(bitfield)}")
      {:ok, %{state | bitfield: bitfield}}
    end
  end

  # -----------------------------------
  #     Handle keep alive and errors
  # -----------------------------------

  defp handle_error(error, state, socket) do
    case error do
      :keep_alive ->
        Logger.error("=== Connection alive")
        send_alive(socket)
        Process.send_after(self(), :cycle, 0)
        {:noreply, state}

      {:error, :timeout} ->
        Process.send_after(self(), :cycle, 100)
        {:noreply, state}

      {:error, :closed} ->
        Logger.error("=== Coneccion closed in worker: #{inspect(self())}")
        :gen_tcp.close(socket)
        {:stop, :normal, state}
    end
  end

  defp send_alive(socket) do
    Logger.info("=== Sending keep alive")
    keep_alive = Messages.keep_alive()
    :gen_tcp.send(socket, keep_alive)
  end
end
