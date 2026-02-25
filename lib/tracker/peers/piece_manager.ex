defmodule Peers.PieceManager do
  alias Exorrent.Torrent

  use GenServer
  require Logger

  @moduledoc """
    Manager of pieces
  """

  @block_size 16384
  # -------------------
  #   GenServer calls
  # -------------------

  def start_link(torrent),
    do: GenServer.start_link(__MODULE__, torrent, name: __MODULE__)

  def store_block(index, begin, block),
    do: GenServer.cast(__MODULE__, {:store_block, index, begin, block})

  def downloading(piece_index),
    do: GenServer.cast(__MODULE__, {:downloading, piece_index})

  def pieces_map(),
    do: GenServer.call(__MODULE__, :pieces)

  def blocks_list(piece_index),
    do: GenServer.call(__MODULE__, {:blocks_list, piece_index})

  def blocks(piece_index),
    do: GenServer.call(__MODULE__, {:blocks, piece_index})

  def status(piece_index),
    do: GenServer.call(__MODULE__, {:status, piece_index})

  def get_if_available(piece_index, offset),
    do: GenServer.call(__MODULE__, {:available, piece_index, offset})

  # ----------------------
  #   GenServer functions
  # ----------------------

  def init(%Torrent{
        total_pieces: total_pieces,
        blocks: blocks,
        piece_length: piece_length,
        size: size
      }) do
    Logger.info("=== Init Piece Manager ===")
    # create dictionary
    # key: piece index
    # value: dicc -> key: block_index, value: block
    pieces_map =
      for piece_index <- 0..(total_pieces - 1), into: %{} do
        block_map = build_block_map(piece_index, total_pieces, piece_length, blocks, size)
        {piece_index, block_map}
      end

    # create piece status
    pieces_status =
      pieces_map
      |> Map.keys()
      |> build_statuses_map()

    pieces_state = %{pieces_map: pieces_map, pieces_status: pieces_status}

    {:ok, pieces_state}
  end

  def handle_cast({:store_block, index, begin, block}, pieces_state) do
    round_index = Integer.floor_div(begin, @block_size)
    pieces_map = pieces_state.pieces_map
    # store block in the memory
    block_map =
      pieces_map
      |> Map.get(index)
      |> Map.put(round_index, block)

    pieces_status =
      case missing_block?(pieces_map, index) do
        false ->
          pieces_state.pieces_status
          |> Map.put(index, :done)

        true ->
          pieces_state.pieces_status
      end

    pieces_map = Map.put(pieces_map, index, block_map)

    pieces_state =
      pieces_state
      |> Map.put(:pieces_map, pieces_map)
      |> Map.put(:pieces_status, pieces_status)

    {:noreply, pieces_state}
  end

  def handle_cast({:dowloading, piece_index}, pieces_state) do
    index = parse_value(piece_index)

    pieces_status =
      pieces_state.pieces_status
      |> Map.put(index, :downloading)

    pieces_state =
      pieces_state
      |> Map.put(:pieces_status, pieces_status)

    {:noreply, pieces_state}
  end

  def handle_call(:pieces, _from, pieces_state),
    do: {:reply, pieces_state.pieces_map, pieces_state}

  def handle_call({:blocks_list, piece_index}, _from, pieces_state) do
    index = parse_value(piece_index)

    block_map =
      pieces_state.pieces_map
      |> Map.get(index)
      |> Map.keys()
      |> :queue.from_list()

    {:reply, block_map, pieces_state}
  end

  def handle_call({:blocks, piece_index}, _from, pieces_state) do
    index = parse_value(piece_index)

    blocks =
      pieces_state.pieces_map
      |> Map.get(index)
      |> Map.values()

    {:reply, blocks, pieces_state}
  end

  # --------------------------------------------------
  #       Tells when a piece is fully donwload
  # --------------------------------------------------
  def handle_call({:status, piece_index}, _from, pieces_state) do
    index = parse_value(piece_index)
    status = pieces_state.pieces_status[index]

    {:reply, status, pieces_state}
  end

  # --------------------------------------------------
  #      Tells when a piece is available to share 
  # --------------------------------------------------
  def handle_call({:available, piece_index, offset}, _from, pieces_state) do
    index = parse_value(piece_index)
    offset = parse_value(offset)

    status = pieces_state.pieces_status[index]

    case status do
      :done ->
        block = pieces_state.pieces_map[index][offset]
        {:reply, {:ok, block}, pieces_state}

      _ ->
        {:reply, :unavailable, pieces_state}
    end
  end

  # --------------------------------------------------
  #                 Private functions
  # --------------------------------------------------

  # --------------------------------------------------
  #  Build the block map from the bitfield of a peer
  # --------------------------------------------------
  defp build_block_map(piece_index, total_pieces, piece_length, blocks, size) do
    num_blocks =
      if piece_index == total_pieces - 1 do
        # last piece, maybe smaller
        (size - (total_pieces - 1) * piece_length)
        |> div(16384)
      else
        blocks
      end

    for block_index <- 0..(num_blocks - 1), into: %{} do
      {block_index, nil}
    end
  end

  # --------------------------------------------------
  #  Piece can have three states
  #  1 - miss
  #  2 - downloading
  #  3 - done
  # --------------------------------------------------
  defp build_statuses_map(indexes) do
    indexes
    |> Enum.map(fn index -> {index, :miss} end)
    |> Map.new()
  end

  defp parse_value(piece_index) when is_binary(piece_index) do
    <<val::32>> = piece_index
    val
  end

  defp parse_value(piece_index),
    do: piece_index

  defp missing_block?(pieces_state, index) do
    pieces_state
    |> Map.get(index)
    |> Enum.any?(fn b -> is_nil(b) end)
  end
end
