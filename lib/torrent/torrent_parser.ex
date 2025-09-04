defmodule Exorrent.TorrentParser do
  alias Exorrent.Decoder
  alias Exorrent.Encoder

  def read_torrent(torrent) do
    with {:ok, bencode} <- File.read(torrent),
         do: Decoder.decode(bencode)
  end

  def get_info_hash(%{"info" => info}) do
    raw_data = Encoder.encode(info)
    # swarm id
    :crypto.hash(:sha, raw_data)
  end

  def get_trackers(%{"announce-list" => announce_list}), do: List.flatten(announce_list)
  def get_trackers(%{"announce" => announce}), do: [announce]

  def size(%{"info" => info}), do: size(info)
  def size(%{"length" => length}), do: length
  def size(%{"files" => files}) do
    files
    |> Enum.map(fn f -> f["length"] end)
    |> Enum.reduce(0, fn size, acc -> size + acc end)
  end
end
