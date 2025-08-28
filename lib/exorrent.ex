defmodule Exorrent do
  alias Exorrent.TorrentParser
  alias Exorrent.Tracker
  alias Exorrent.PeerManager

  def exorrent() do
    {:ok, torrent} = TorrentParser.read_torrent("test.torrent")

    conn = Tracker.get_peers(torrent)
    response = Tracker.announce(conn.conn_id, torrent)

    # init swarm of peers

    {:ok, _pid} = PeerManager.start_link(response.peers)
    PeerManager.broadcast()
  end

  def reconnect() do
    Tracker.conn_down()
    PeerManager.kill()
    exorrent()
  end
end
