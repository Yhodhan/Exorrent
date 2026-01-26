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

  def pieces_map(),
    do: GenServer.call(__MODULE__, :pieces)

  def blocks_list(piece_index),
    do: GenServer.call(__MODULE__, {:blocks_list, piece_index})

  def blocks(piece_index),
    do: GenServer.call(__MODULE__, {:blocks, piece_index})

  def is_done?(piece_index),
    do: GenServer.call(__MODULE__, {:is_done?, piece_index})

  # ----------------------
  #   GenServer functions
  # ----------------------

  def init(%Torrent{
        total_pieces: total_pieces,
        blocks: blocks,
        piece_length: piece_length,
        size: size
      }) do
    # create dictionary
    # key: piece index
    # value: dicc -> key: block_index, value: block
    pieces_map =
      for piece_index <- 0..(total_pieces - 1), into: %{} do
        block_map = build_block_map(piece_index, total_pieces, piece_length, blocks, size)
        {piece_index, block_map}
      end

    {:ok, pieces_map}
  end

  def handle_cast({:store_block, index, begin, block}, piece_map) do
    round_index = Integer.floor_div(begin, @block_size)
    # store block in the memory
    block_map =
      Map.get(piece_map, index)
      |> Map.put(round_index, block)

    {:noreply, Map.put(piece_map, index, block_map)}
  end

  def handle_call(:pieces, _from, piece_map),
    do: {:reply, piece_map, piece_map}

  def handle_call({:blocks_list, piece_index}, _from, piece_map) do
    index = parse_index(piece_index)

    block_map =
      piece_map
      |> Map.get(index)
      |> Map.keys()
      |> :queue.from_list()

    {:reply, block_map, piece_map}
  end

  def handle_call({:blocks, piece_index}, _from, piece_map) do
    index = parse_index(piece_index)

    blocks =
      piece_map
      |> Map.get(index)
      |> Map.values()

    {:reply, blocks, piece_map}
  end

  # return true if there is a missing block
  def handle_call({:is_done?, piece_index}, _from, piece_map) do
    index = parse_index(piece_index)

    done? =
      piece_map
      |> Map.get(index)
      |> Enum.any?(fn b -> is_nil(b) end)

    {:reply, done?, piece_map}
  end

  # -------------------
  #  Private functions
  # -------------------
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

  defp parse_index(piece_index) when is_binary(piece_index) do
    <<val::32>> = piece_index
    val
  end

  defp parse_index(piece_index),
    do: piece_index
end
