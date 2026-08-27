defmodule Exorrent.PieceManager do
  alias Exorrent.Torrent

  use GenServer
  require Logger

  @moduledoc """
  """

  defstruct [
    :hashes,
    :bitmap,
    :piece_length,
    # %{piece_index => %{blocks_received: bitfield_or_mapset, buffer: <<>>}} — small, bounded working set
    :downloading,
    :size,
    :total_blocks,
    :total_pieces
  ]

  @block_size 16384
  # -------------------
  #   GenServer calls
  # -------------------

  def start_link(torrent),
    do: GenServer.start_link(__MODULE__, torrent, name: __MODULE__)

  def store_block(index, begin, block),
    do: GenServer.cast(__MODULE__, {:store_block, index, begin, block})

  def bitfield(),
    do: GenServer.call(__MODULE__, :bitfield)

  def blocks_list(piece_index),
    do: GenServer.call(__MODULE__, {:blocks_list, piece_index})

  def status(piece_index),
    do: GenServer.call(__MODULE__, {:status, piece_index})

  def get_if_available(piece_index, offset),
    do: GenServer.call(__MODULE__, {:available, piece_index, offset})

  def validate_piece(piece_index, type),
    do: GenServer.call(__MODULE__, {:validate_piece, piece_index, type})

  def update_status(piece_index, status),
    do: GenServer.call(__MODULE__, {:update_status, piece_index, status})

  def request_work(),
    do: GenServer.call(__MODULE__, :request_work)

  def request_work_bitmap(bitmap),
    do: GenServer.call(__MODULE__, {:request_work_bitmap, bitmap})

  # ----------------------
  #   GenServer functions
  # ----------------------

  def init(%Torrent{
        total_pieces: total_pieces,
        piece_length: piece_length,
        size: size,
        hashes: hashes,
        blocks: blocks
      }) do
    Logger.info("=== Init Piece Manager ===")

    new_bitmap = new_bitmap(total_pieces)
    downloading = %{}

    {:ok,
     %__MODULE__{
       bitmap: new_bitmap,
       downloading: downloading,
       hashes: hashes,
       piece_length: piece_length,
       total_pieces: total_pieces,
       size: size,
       total_blocks: blocks
     }}
  end

  def handle_cast({:store_block, index, begin, block}, pieces_state) do
    block_index = Integer.floor_div(begin, @block_size)

    # store block in the memory
    download = Map.get(pieces_state.downloading, index, %{})
    update_download = Map.put(download, block_index, block)
    downloading = Map.put(pieces_state.downloading, index, update_download)

    {:noreply, %{pieces_state | downloading: downloading}}
  end

  def handle_call(:bitfield, _from, pieces_state),
    do: {:reply, pieces_state.bitmap, pieces_state}

  def handle_call({:blocks_list, piece_index}, _from, pieces_state) do
    {:reply, get_index_block_map(piece_index, pieces_state), pieces_state}
  end

  # --------------------------------------------------
  #       Tells when a piece is fully donwload
  # --------------------------------------------------
  def handle_call({:status, piece_index}, _from, pieces_state) do
    index = parse_value(piece_index)

    done = has_piece?(pieces_state.bitmap, index)
    downloading = Map.has_key?(pieces_state.downloading, index)

    cond do
      downloading -> {:reply, :downloading, pieces_state}
      done -> {:reply, :done, pieces_state}
      true -> {:reply, :miss, pieces_state}
    end
  end

  # --------------------------------------------------
  #      Tells when a piece is available to share 
  # --------------------------------------------------
  def handle_call({:available, piece_index, _offset}, _from, pieces_state) do
    index = parse_value(piece_index)

    status = has_piece?(pieces_state.bitmap, index)

    if status,
      do: {:reply, :ok, pieces_state},
      else: {:reply, :unavailable, pieces_state}
  end

  # --------------------------------------------------
  #         Validate a block against its hash 
  # --------------------------------------------------
  def handle_call({:validate_piece, piece_index, _type}, _from, pieces_state) do
    index = parse_value(piece_index)
    # offset = parse_value(offset)
    case validate(index, pieces_state) do
      {:ok, piece} ->
        updated_map = update_bitmap(pieces_state.bitmap, index)
        {:reply, {:ok, piece}, %{pieces_state | bitmap: updated_map}}

      {:error, piece} ->
        {:reply, {:error, piece}, pieces_state}
    end
  end

  # -----------------------------------------------------------------------------------

  def handle_call(:request_work, _from, pieces_state) do
    # find first missing piece
    piece_index = get_missing_piece_index(pieces_state.bitmap, 0)

    if piece_index < pieces_state.total_pieces,
      do: {:reply, {:ok, piece_index}, pieces_state},
      else: {:reply, {:none, nil}, pieces_state}
  end

  # -----------------------------------------------------------------------------------

  def handle_call({:request_work_bitmap, bitmap}, _from, pieces_state) do
    # get the first piece of the bitmap that is missing
    index =
      0..(pieces_state.total_pieces - 1)
      |> Enum.find(fn i -> has_piece?(bitmap, i) and not has_piece?(pieces_state.bitmap, i) end)

    case index do
      nil ->
        {:reply, {:none, nil}, pieces_state}

      val ->
        {:reply, {:ok, val}, pieces_state}
    end
  end

  # maybe this functions is not needed anymore 
  def handle_call({:update_status, _piece_index, _status}, _from, pieces_state) do
    {:reply, :ok, pieces_state}
  end

  # --------------------------------------------------
  #                 Private functions
  # --------------------------------------------------

  # --------------------------------------------------
  #        Obtain the block map from a piece 
  # --------------------------------------------------
  def get_index_block_map(piece_index, pieces_state) do
    index = parse_value(piece_index)

    build_block_map(
      index,
      pieces_state.total_pieces,
      pieces_state.piece_length,
      pieces_state.total_blocks,
      pieces_state.size
    )
    |> :queue.from_list()
  end

  # --------------------------------------------------
  #    Build the block request list for a peer 
  # --------------------------------------------------
  defp build_block_map(piece_index, total_pieces, piece_length, blocks, size) do
    num_blocks =
      if piece_index == total_pieces - 1 do
        # last piece, maybe smaller
        (size - (total_pieces - 1) * piece_length)
        |> div(@block_size)
      else
        blocks
      end

    for block_index <- 0..(num_blocks - 1), into: [] do
      block_index
    end
  end

  # ------------------------
  #     Private functions
  # ------------------------

  defp new_bitmap(total_pieces) do
    byte_count = ceil(total_pieces / 8)
    <<0::size(byte_count * 8)>>
  end

  defp update_bitmap(bitmap, index) do
    <<prefix::size(^index), _::size(1), rest::bitstring>> = bitmap
    <<prefix::size(index), 1::size(1), rest::bitstring>>
  end

  defp has_piece?(bitmap, index) do
    <<_::size(^index), bit::1, _::bitstring>> = bitmap
    bit === 1
  end

  defp get_missing_piece_index(<<>>, index),
    do: index

  defp get_missing_piece_index(<<bit::1, rest::bitstring>>, index) do
    if bit == 0,
      do: index,
      else: get_missing_piece_index(rest, index + 1)
  end

  # --------------------------------------------------
  #  Piece can have three states
  #  1 - miss
  #  2 - downloading
  #  3 - done
  # --------------------------------------------------
  defp parse_value(piece_index) when is_binary(piece_index) do
    <<val::32>> = piece_index
    val
  end

  defp parse_value(piece_index),
    do: piece_index

  # -----------------------------------
  #          Validates a piece
  # -----------------------------------
  defp unify_blocks([]),
    do: <<>>

  defp unify_blocks([block | rest]),
    do: block <> unify_blocks(rest)

  defp validate(index, %{downloading: downloading, hashes: hashes} = _pieces_state) do
    downloading
    |> Map.get(index)
    |> Enum.sort_by(fn {k, _v} -> k end)
    |> Enum.map(fn {_k, v} -> v end)
    |> unify_blocks()
    |> validation(hashes)
  end

  defp validation(piece, hashes) do
    hash = :crypto.hash(:sha, piece)

    if MapSet.member?(hashes, hash),
      do: {:ok, piece},
      else: {:error, piece}
  end
end
