defmodule Exorrent do
  alias Exorrent.TorrentParser
  alias Exorrent.Tracker

  def exorrent() do
    {:ok, torrent} = TorrentParser.read_torrent("test.torrent")

    conn = Tracker.get_peers(torrent)
    Tracker.announce(conn.conn_id, torrent)
  end
end
