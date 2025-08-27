defmodule Exorrent do
  alias Exorrent.TorrentParser
  alias Exorrent.Tracker

  def exorrent() do
    {:ok, torrent} = TorrentParser.read_torrent("test.torrent")

    {:connection, tx_id, conn_id} = Tracker.get_peers(torrent)
    Tracker.announce(tx_id, conn_id)
  end
end
