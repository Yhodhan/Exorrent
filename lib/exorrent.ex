defmodule Exorrent do
  alias Exorrent.TorrentParser
  alias Exorrent.Tracker
  alias Exorrent.PeerManager
  alias Exorrent.PeerConnection

  def connection() do
    {:ok, torrent} = TorrentParser.read_torrent("bunny.torrent")

    peers = Tracker.get_peers(torrent)
    # init swarm of peers
#    {:ok, _pid} = PeerManager.start_link(peers)
    peers
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
    {:ok, torrent} = TorrentParser.read_torrent("bunny.torrent")
    torrent
  end
end
