defmodule Peers.Worker do
  # alias Peers.DownloadTable
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

  def handle_info(:cycle, %{status: :idle, interested: true, bitfield: bitfield} = state)
      when not is_nil(bitfield) do
    # start requesting
    Logger.debug("=== Bitfield obtained, init request")

    Logger.debug("=== Bitfield: #{inspect(bitfield)}")

    piece_in = :queue.get(bitfield)

    Logger.debug("=== Dequeue piece: #{inspect(piece_in)}")

    {:ok, state} =
      :queue.get(bitfield)
      |> prepare_request(state)

    Process.send_after(self(), :cycle, 10)

    {:noreply, state}
  end

  def handle_info(:cycle, %{socket: socket, status: :idle, interested: true} = state) do
    Logger.info("=== Worker Cycle")

    case receive_message(socket, state) do
      {:downloading, state} ->
        {:continue, state}

      {:ok, state} ->
        Process.send_after(self(), :cycle, 10)
        {:noreply, state}

      {:stop, state} ->
        {:stop, :normal, state}
    end
  end

  def handle_info(
        :cycle,
        %{status: :downloading, socket: socket, requested: {piece_index, blocks_list}} = state
      ) do
    # download piece
    block_index = :queue.get(blocks_list)

    Logger.debug(
      "parameters to querest, ind: #{inspect(piece_index)}, block: #{inspect(block_index)}, size: #{inspect(@block_size)}"
    )

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
    case receive_message(socket, state) do
      {:downloading, state} ->
        {:continue, state}

      {:ok, state} ->
        Process.send_after(self(), :cycle, 10)

        {:noreply, state}
    end
  end

  # -------------------
  #  Private functions
  # -------------------

  def receive_message(socket, state) do
    with {:ok, <<len::32>>} <- :gen_tcp.recv(socket, 4, 100),
         {:ok, id, len} <- peer_message(len, socket) do
      Logger.debug("=== Process message")
      process_message(id, len, state)
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

      {:downloading, state}
    end
  end

  def process_message(5, len, %{socket: socket, total_pieces: total_pieces} = state) do
    with {:ok, bitfield} <- :gen_tcp.recv(socket, len) do
      Logger.info("=== Bitfield obtained: #{inspect(bitfield)}")

      {:ok, %{state | bitfield: Messages.make_bitfield(bitfield, total_pieces)}}
    end
  end

  def process_message(7, len, %{socket: socket} = state) do
    with {:ok, <<index::32>>} <- :gen_tcp.recv(socket, 4),
         {:ok, <<begin::32>>} <- :gen_tcp.recv(socket, 4),
         {:ok, <<block::binary>>} <- :gen_tcp.recv(socket, len - 8) do
      Logger.debug("=== Block obtained: #{inspect(block)}")

      PieceManager.store_block(index, begin, block)

      {:downloading, state}
    end
  end

  # -------------------
  #    Pieces request
  # -------------------
  def prepare_request(piece_index, state) do
    Logger.debug("=== preparing request piece_index: #{inspect(piece_index)}")
    blocks_list = PieceManager.blocks_list(piece_index)

    {:ok, %{state | status: :downloading, requested: {piece_index, blocks_list}}}
  end

  #  defp mark_as_done(piece_index) do
  #    DownloadTable.mark_as_done(piece_index)
  #  end

  # -----------------------------------
  #     Handle keep alive and errors
  # -----------------------------------

  defp handle_error(error, state, socket) do
    case error do
      :keep_alive ->
        Logger.error("=== Connection alive")
        send_alive(socket)
        Process.send_after(self(), :cycle, 0)
        {:ok, state}

      {:error, :timeout} ->
        Process.send_after(self(), :cycle, 100)
        {:ok, state}

      {:error, :closed} ->
        Logger.error("=== Coneccion closed in worker: #{inspect(self())}")
        :gen_tcp.close(socket)
        {:stop, state}
    end
  end

  defp send_alive(socket) do
    Logger.info("=== Sending keep alive")
    keep_alive = Messages.keep_alive()
    :gen_tcp.send(socket, keep_alive)
  end
end
