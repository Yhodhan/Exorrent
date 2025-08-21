defmodule Exorrent do
  alias BencodeDecoder.Decoder

  def read_torrent(torrent) do
    with {:ok, bencode} <- File.read(torrent),
         {:ok, decode, _} <- Decoder.decode_bencode(bencode) do
      {:ok, decode}
    end
  end

  def exorrent() do
    {:ok, torrent} = read_torrent("puppy.torrent")

    Tracker.create_tracker(torrent)
  end

  # private functions

end
