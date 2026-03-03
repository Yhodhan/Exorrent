defmodule Exorrent.Torrent do
  alias Bencoder.Decoder
  alias Exorrent.InfoHash

  require Logger

  @block_size 16384

  defstruct [
    :name,
    :info_hash,
    :size,
    :type,
    :urls,
    :total_pieces,
    :piece_length,
    :pieces_list,
    :blocks
  ]

  def read_torrent(torrent) do
    with {:ok, bencode} <- File.read(torrent),
         {:ok, torr} <- Decoder.decode(bencode),
         {:ok, info_hash} <- InfoHash.raw_info_hash(bencode),
         {:ok, type} <- get_type(torr),
         {:ok, urls} <- get_urls(torr),
         {:ok, piece_length} <- piece_length(torr),
         {:ok, pieces_list} <- get_pieces_list(torr),
         size <- size(torr) do
      {:ok,
       %__MODULE__{
         name: get_name(torr),
         info_hash: info_hash,
         size: size,
         type: type,
         urls: urls,
         total_pieces: amount_pieces(torr),
         piece_length: piece_length,
         pieces_list: MapSet.new(pieces_list),
         blocks: blocks(piece_length)
       }}
    else
      error ->
        Logger.error("=== failed creating #{inspect(error)}")
    end
  end

  # ---------------------------------------------------
  def get_name(%{"info" => info}),
    do: info["name"]

  # ---------------------------------------------------
  def amount_pieces(%{"info" => info}),
    do: div(byte_size(info["pieces"]), 20)

  # ---------------------------------------------------
  def blocks(piece_length),
    do: div(piece_length, @block_size)

  # ---------------------------------------------------
  def get_type(torrent) do
    if Map.has_key?(torrent, "url-list") do
      {:ok, :webseeds}
    else
      {:ok, :trackers}
    end
  end

  # ---------------------------------------------------

  def piece_length(%{"info" => info}),
    do: {:ok, info["piece length"]}

  # ---------------------------------------------------

  def get_pieces_list(%{"info" => info}) do
    {:ok,
     info["pieces"]
     |> pieces_hashes()}
  end

  def pieces_hashes(<<>>),
    do: []

  def pieces_hashes(<<hash::binary-size(20), rest::binary>>),
    do: [hash] ++ pieces_hashes(rest)

  # ---------------------------------------------------
  #                        Trackers
  # ---------------------------------------------------
  def get_urls(%{"url-list" => url_list}),
    do: {:ok, List.flatten(url_list)}

  def get_urls(%{"announce-list" => announce_list}),
    do: {:ok, List.flatten(announce_list)}

  def get_urls(%{"announce" => announce}),
    do: {:ok, [announce]}

  # ---------------------------------------------------

  def size(%{"info" => info}), do: size(info)
  def size(%{"length" => length}), do: length

  def size(%{"files" => files}) do
    files
    |> Enum.map(fn f -> f["length"] end)
    |> Enum.reduce(0, fn size, acc -> size + acc end)
  end
end
