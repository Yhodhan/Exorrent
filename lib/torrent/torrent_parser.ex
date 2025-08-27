defmodule Exorrent.TorrentParser do
  alias Exorrent.Decoder
  alias Exorrent.Encoder

  def read_torrent(torrent) do
    with {:ok, bencode} <- File.read(torrent),
         {:ok, decode, _} <- Decoder.decode_bencode(bencode) do
      {:ok, decode}
    end
  end

  def get_info_hash(torrent) do
    raw_data =
      torrent["info"]
      |> Encoder.encode()

    # swarm id
    :crypto.hash(:sha, raw_data)
  end

  def get_trackers_list(torrent) do
    announce = torrent["announce"]
    announce_list = torrent["announce-list"]

    unless is_nil(announce_list) do
      List.flatten(announce_list)
    else
      [announce]
    end
  end
end
