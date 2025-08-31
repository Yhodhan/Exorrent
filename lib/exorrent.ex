defmodule Exorrent do
  alias Exorrent.TorrentParser
  alias Exorrent.Tracker
  alias Exorrent.PeerManager

  def connection() do
    {:ok, torrent} = TorrentParser.read_torrent("test.torrent")

    conn = Tracker.get_peers(torrent)
    response = Tracker.announce(conn.conn_id, torrent)

    # init swarm of peers

    {:ok, _pid} = PeerManager.start_link(response.peers)
    # PeerManager.broadcast()
  end

  def broadcast() do
    PeerManager.broadcast()
  end

  def check_peers() do
    PeerManager.check_peer_connection()
  end

  def reconnect() do
    Tracker.conn_down()
    PeerManager.kill()
    connection()
  end
end
