defmodule Exorrent.Torrent do
  alias Bencoder.Decoder
  alias Bencoder.Encoder

  require Logger

  defstruct [:info_hash, :size, :trackers, :total_pieces, :piece_length, :pieces_map]

  def read_torrent(torrent) do
    with {:ok, bencode} <- File.read(torrent),
         {:ok, torr} <- Decoder.decode(bencode),
         {:ok, info_hash} <- get_info_hash(torr),
         {:ok, trackers} <- get_trackers(torr),
         {:ok, piece_length} <- piece_length(torr),
         {:ok, pieces_map} <- get_pieces_map(torr),
         size <- size(torr) do
      {:ok,
       %__MODULE__{
         info_hash: info_hash,
         size: size,
         trackers: trackers,
         total_pieces: amount_pieces(torr),
         piece_length: piece_length,
         pieces_map: pieces_map
       }}
    else
      error ->
        Logger.error("=== failed creating #{inspect(error)}")
    end
  end

  def amount_pieces(%{"info" => info}),
    do: div(byte_size(info["pieces"]), 20)

  # ------------------

  def piece_length(%{"info" => info}),
    do: {:ok, info["piece length"]}

  # -----------------

  def get_pieces_map(%{"info" => info}),
    do: {:ok, pieces_hashes(info["pieces"])}

  def pieces_hashes(<<>>),
    do: []

  def pieces_hashes(<<hash::binary-size(20), rest::binary>>) do
    [hash] ++ pieces_hashes(rest)
  end

  # -----------------

  def get_info_hash(%{"info" => info}) do
    {:ok, raw_data} = Encoder.encode(info)
    {:ok, :crypto.hash(:sha, raw_data)}
  end

  # -----------------

  def get_trackers(%{"announce-list" => announce_list}),
    do: {:ok, List.flatten(announce_list)}

  def get_trackers(%{"announce" => announce}),
    do: {:ok, [announce]}

  # -----------------
  #    Trackers
  # -----------------

  def size(%{"info" => info}), do: size(info)
  def size(%{"length" => length}), do: length

  def size(%{"files" => files}) do
    files
    |> Enum.map(fn f -> f["length"] end)
    |> Enum.reduce(0, fn size, acc -> size + acc end)
  end
end
