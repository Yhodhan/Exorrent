defmodule Exorrent do
  alias Exorrent.Decoder
  alias Exorrent.Tracker

  def read_torrent(torrent) do
    with {:ok, bencode} <- File.read(torrent),
         {:ok, decode, _} <- Decoder.decode_bencode(bencode) do
      {:ok, decode}
    end
  end

  def exorrent() do
    {:ok, torrent} = read_torrent("test.torrent")

    {:connection, tx_id, conn_id} = Tracker.get_peers(torrent)
    Tracker.announce(tx_id, conn_id)
  end
end
