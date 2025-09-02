defmodule Exorrent do
  alias Exorrent.TorrentParser
  alias Exorrent.Tracker
  alias Exorrent.PeerManager
  alias Exorrent.PeerConnection

  def connection() do
    {:ok, torrent} = TorrentParser.read_torrent("test.torrent")

    Tracker.get_peers(torrent)
    # response = Tracker.announce(conn.conn_id, torrent)

    # init swarm of peers
    # {:ok, _pid} = PeerManager.start_link(response.peers)

    # tracker is no longer needed
    # Tracker.conn_down()

    # response.peers
  end

  def init_handshake(torrent) do
    # just one peer for now
    peers = get_connected_peers()

    Enum.map(peers, fn peer ->
      handshake_msg = PeerConnection.build_handshake(torrent)

      PeerConnection.send_handshake(peer.pid, handshake_msg)

      PeerConnection.tcp_response(peer.pid)
    end)
  end

  # -------------------
  #       helpers
  # -------------------

  def broadcast() do
    PeerManager.broadcast()
  end

  def check_peers_status() do
    PeerManager.check_peers_connections()
  end

  def get_peers() do
    PeerManager.get_peers()
  end

  def get_connected_peers() do
    PeerManager.get_connected_peers()
  end

  def terminate_unconnected_peers() do
    PeerManager.terminate_unconnected_peers()
  end

  def reconnect() do
    PeerManager.kill()
    connection()
  end

  # helper
  def torrent() do
    {:ok, torrent} = TorrentParser.read_torrent("test.torrent")
    torrent
  end
end
