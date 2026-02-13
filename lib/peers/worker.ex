defmodule Peers.Worker do
  alias Peers.Messages
  alias Peers.PieceManager
  alias Peers.PeerManager

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
  # --------------------

  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, state}
  end

  # --------------------------------------------------

  def handle_info(
        :cycle,
        %{socket: socket, status: :idle, choke: true, interested: false} = state
      ) do
    Logger.info("=== Send interest message ===")

    interes = Messages.interested()
    :gen_tcp.send(socket, interes)

    Process.send_after(self(), :cycle, 1)

    {:noreply, %{state | interested: true}}
  end

  # --------------------------------------------------

  def handle_info(:cycle, %{status: :idle, interested: true, bitfield: true} = state) do
    Process.send_after(self(), :cycle, 2)

    with {:ok, piece} <- PeerManager.request_work(self()),
         :miss <- PieceManager.status(piece) do
      {:ok, state} = prepare_request(piece, state)

      {:noreply, state, {:continue, :downloading}}
    else
      _ ->
        {:noreply, state}
    end
  end

  # --------------------------------------------------

  def handle_info(:cycle, %{socket: socket, status: :idle, interested: true} = state) do
    Logger.info("=== Worker Cycle ===")

    # Process.sleep(10000)
    receive_message(socket, state)
  end

  # --------------------------------------------------

  def handle_info(
        :cycle,
        %{status: :downloading, socket: socket, requested: {piece_index, blocks_list}} = state
      ) do
    # download piece
    cond do
      not :queue.is_empty(blocks_list) ->
        block_index = :queue.get(blocks_list)

        Logger.info(
          "=== Parameters to request, piece_index: #{inspect(piece_index)}, block_index: #{inspect(block_index)}, block_offset: #{inspect(block_index * @block_size)} ==="
        )

        request_msg = Messages.request(piece_index, block_index * @block_size, @block_size)
        :gen_tcp.send(socket, request_msg)

        {:noreply, state, {:continue, :downloading}}

      true ->
        case validate_piece(piece_index, state.pieces_list) do
          {:ok, verified_piece} ->
            Logger.debug("=== Verified piece ===")

            # Init write to disk
            Logger.debug("=== Write to disk ===")

            :ok = DiskManager.write_piece(piece_index, verified_piece)

            Logger.debug("=== Done keep cycle ===")
            # Keep cycle
            # Fetch next bitfield index
            Process.send_after(self(), :cycle, 2)
            {:noreply, %{state | status: :idle}}

          _ ->
            Logger.error("=== Piece could not be verified, retry download ===")
            # retry download
            {:noreply, %{state | status: :idle, interested: true}}
        end
    end
  end

  # --------------------------------------------------

  def handle_info(msg, state) do
    Logger.warning("=== Unhandled message in #{inspect(self())}: #{inspect(msg)} ===")
    Process.sleep(2000)
    {:noreply, state}
  end

  # --------------------------------------------------

  def handle_continue(:downloading, %{socket: socket} = state) do
    Logger.debug("=== Enter handle continue ===")

    receive_message(socket, state)
  end

  # -------------------
  #  Private functions
  # -------------------

  def receive_message(socket, state) do
    with {:ok, <<len::32>>} <- :gen_tcp.recv(socket, 4, 100),
         {:ok, id, len} <- peer_message(len, socket) do
      Logger.debug("=== Process message ===")

      case process_message(id, len, state) do
        {:block_obtained, state} ->
          Process.send_after(self(), :cycle, 5)
          {:noreply, state}

        {:downloading, state} ->
          {:noreply, state, {:continue, :downloading}}

        {:ok, state} ->
          Process.send_after(self(), :cycle, 5)

          {:noreply, state}
      end
    else
      error ->
        handle_error(error, state, socket)
    end
  end

  def peer_message(0, _socket),
    do: :keep_alive

  def peer_message(len, socket) do
    with {:ok, <<id::8>>} <- :gen_tcp.recv(socket, 1, 100),
         do: {:ok, id, len - 1}
  end

  # choke
  def process_message(0, _len, state) do
    Logger.info("=== choked message ===")
    {:ok, %{state | choke: true}}
  end

  # unchoke
  def process_message(1, _len, state) do
    Logger.info("=== unchoked message ===")
    {:ok, %{state | choke: false, unchoked: true}}
  end

  # Interested
  def process_message(2, _len, state) do
    Logger.info("=== interested message ===")
    {:ok, %{state | interested: true}}
  end

  # Not interested
  def process_message(3, _len, state) do
    Logger.info("=== not interested message ===")
    {:ok, %{state | interested: false}}
  end

  # Have
  def process_message(4, len, %{socket: socket} = state) do
    with {:ok, piece_index} <- :gen_tcp.recv(socket, len) do
      Logger.info("=== Piece index: #{inspect(piece_index)} ===")

      <<index::32>> = piece_index

      case PieceManager.status(index) do
        :miss ->
          {:ok, state} = prepare_request(index, state)
          {:downloading, state}

        _ ->
          {:ok, state}
      end
    end
  end

  # Bitfield
  def process_message(5, len, %{socket: socket, total_pieces: total_pieces} = state) do
    with {:ok, bitfield} <- :gen_tcp.recv(socket, len) do
      bitmap = Messages.make_bitfield(bitfield, total_pieces)
      PeerManager.store_bitfield(self(), bitmap)

      {:noreply, %{state | status: :idle, interested: true}}
    end
  end

  def process_message(7, len, %{socket: socket, requested: {piece_index, block_list}} = state) do
    with {:ok, <<index::32>>} <- :gen_tcp.recv(socket, 4),
         {:ok, <<begin::32>>} <- :gen_tcp.recv(socket, 4),
         {:ok, <<block::binary>>} <- :gen_tcp.recv(socket, len - 8) do
      Logger.debug("=== Block obtained ===")

      IO.inspect(len, label: "Len of the block")
      IO.inspect(index, label: "index block")
      IO.inspect(Integer.floor_div(begin, @block_size), label: "Begin block index")

      floor_index = Integer.floor_div(begin, @block_size)

      PieceManager.store_block(index, begin, block)

      case :queue.out(block_list) do
        {{:value, block_index}, remain_blocks} ->
          # verificates that the obtained block isnt repeated
          if floor_index != block_index,
            do: {:block_obtained, %{state | requested: {piece_index, block_list}}},
            else: {:block_obtained, %{state | requested: {piece_index, remain_blocks}}}

        _queue ->
          {:block_obtained, %{state | requested: {piece_index, block_list}}}
      end
    end
  end

  # ----------------------------
  #   Pieces request and build
  # ----------------------------

  def prepare_request(piece_index, state) do
    Logger.debug("=== preparing request piece_index: #{inspect(piece_index)} ===")
    blocks_list = PieceManager.blocks_list(piece_index)

    {:ok, %{state | status: :downloading, requested: {piece_index, blocks_list}}}
  end

  def validate_piece(piece_index, pieces_list) do
    blocks =
      piece_index
      |> PieceManager.blocks()

    piece = unify_blocks(blocks)
    hash = :crypto.hash(:sha, piece)

    if MapSet.member?(pieces_list, hash),
      do: {:ok, piece},
      else: {:error, piece}
  end

  def unify_blocks([]),
    do: <<>>

  def unify_blocks([block | rest]),
    do: block <> unify_blocks(rest)

  # -----------------------------------
  #     Handle keep alive and errors
  # -----------------------------------

  defp handle_error(error, state, socket) do
    case error do
      :keep_alive ->
        Logger.error("=== Connection alive ===")
        send_alive(socket)
        Process.send_after(self(), :cycle, 0)
        {:noreply, state}

      {:error, :timeout} ->
        Logger.debug("=== Reponse timeout, retry ===")
        Process.send_after(self(), :cycle, 100)
        {:noreply, state}

      {:error, :closed} ->
        Logger.error("=== Coneccion closed in worker: #{inspect(self())} ===")
        :gen_tcp.close(socket)
        {:stop, :closed, state}
    end
  end

  defp send_alive(socket) do
    Logger.info("=== Sending keep alive ===")
    keep_alive = Messages.keep_alive()
    :gen_tcp.send(socket, keep_alive)
  end
end
