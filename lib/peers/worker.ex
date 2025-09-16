defmodule Peers.Worker do
  alias Peers.DownloadTable
  alias Peers.Messages
  alias Peers.PieceManager

  use GenServer

  require Logger

  @block_size 16384
  # -------------------
  #   GenServer calls
  # -------------------

  def start_link(state \\ %{}),
    do: GenServer.start_link(__MODULE__, state)

  def return_state(pid),
    do: GenServer.call(pid, :state)

  def init_cycle(pid),
    do: send(pid, :cycle)

  def bitfield_map(pid),
    do: GenServer.call(pid, :bitfield)

  # ----------------------
  #   GenServer functions
  # ----------------------

  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, state}
  end

  def handle_call(:bitfield, _from, state),
    do: {:reply, state.bitfield, state}

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

  def handle_info(
        :cycle,
        %{socket: socket, status: :idle, interested: true} = state
      ) do
    # Logger.info("=== Worker Cycle")
    receive_message(socket, state)
  end

  def handle_info(:cycle, %{status: :idle, interested: true, bitfield: bitfield} = state)
      when not is_nil(bitfield) do
    # start requesting

    {:ok, state} =
      :queue.get(bitfield)
      |> prepare_request(state)

    Process.send_after(self(), :cycle, 10)

    {:noreply, state}
  end

  def handle_info(
        :cycle,
        %{status: :downloading, socket: socket, requested: {piece_index, blocks_list}} = state
      ) do
    # download piece
    block_index = :queue.get(blocks_list)
    request_msg = Messages.request(piece_index, block_index, @block_size)

    :gen_tcp.send(socket, request_msg)

    {:continue, :downloading, state}
  end

  def handle_info(msg, state) do
    Logger.warning("=== Unhandled message in #{inspect(self())}: #{inspect(msg)}")
    Process.sleep(2000)
    {:noreply, state}
  end

  def handle_continue(
        :downloading,
        %{socket: socket, requested: {piece_index, block_list}} = state
      ) do
    receive_message(socket, state)
  end

  # -------------------
  #  Private functions
  # -------------------

  def receive_message(socket, state) do
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

  def peer_message(0, _socket),
    do: :keep_alive

  def peer_message(len, socket) do
    with {:ok, <<id::8>>} <- :gen_tcp.recv(socket, 1, 100) do
      {:ok, id, len - 1}
    end
  end

  # choke
  def process_message(0, _len, state) do
    Logger.info("=== choked message")
    {:ok, %{state | choke: true}}
  end

  # unchoke
  def process_message(1, _len, state) do
    Logger.info("=== unchoked message")
    {:ok, %{state | choke: false, unchoked: true}}
  end

  # interested
  def process_message(2, _len, state) do
    Logger.info("=== interested message")
    {:ok, %{state | interested: true}}
  end

  # not interested
  def process_message(3, _len, state) do
    Logger.info("=== not interested message")
    {:ok, %{state | interested: false}}
  end

  # have
  def process_message(4, len, %{socket: socket} = state) do
    with {:ok, piece_index} <- :gen_tcp.recv(socket, len) do
      Logger.info("=== Piece index: #{inspect(piece_index)}")

      {:ok, state} = prepare_request(piece_index, state)

      {:noreply, state}
    end
  end

  def process_message(5, len, %{socket: socket, total_pieces: total_pieces} = state) do
    with {:ok, bitfield} <- :gen_tcp.recv(socket, len) do
      Logger.info("=== Bitfield obtained: #{inspect(bitfield)}")

      {:ok,
       %{state | bitfield: Messages.make_bitfield(bitfield, total_pieces), got_bitfield: true}}
    end
  end

  def process_message(7, len, %{socket: socket} = state) do
    with {:ok, <<index::32>>} <- :gen_tcp.recv(socket, 4),
         {:ok, <<begin::32>>} <- :gen_tcp.recv(socket, 4),
         {:ok, <<block::binary>>} <- :gen_tcp.recv(socket, len - 8) do
      Logger.debug("=== Block obtained: #{inspect(block)}")

      PieceManager.store_block(index, begin, block)
      {:ok, state}
    end
  end

  # -------------------
  #    Pieces request
  # -------------------
  def prepare_request(piece_index, state) do
    blocks_list = PieceManager.blocks_list(piece_index)

    {:ok, %{state | status: :downloading, requested: {piece_index, blocks_list}}}
  end

  defp mark_as_done(piece_index) do
    DownloadTable.mark_as_done(piece_index)
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
