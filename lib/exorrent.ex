defmodule Exorrent do
  alias Exorrent.TorrentParser
  alias Exorrent.Tracker
  alias Exorrent.PeerManager
  alias Exorrent.PeerConnection

  @torrent "ubuntu.torrent"

  def connection() do
    {:ok, torrent} = TorrentParser.read_torrent(@torrent)

    peers = Tracker.get_peers(torrent)
    # init swarm of peers
    PeerManager.start_link(peers)

    broadcast()
  end

  def init_handshake() do
    torr = torrent()
    # just one peer for now
    [peer | _] = get_connected_peers()

    # Enum.map(peers, fn peer ->
    handshake = PeerConnection.build_handshake(torr)

    PeerConnection.send_handshake(peer.pid, handshake)

    PeerConnection.tcp_response(peer.pid)
    # end)
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
    {:ok, torrent} = TorrentParser.read_torrent(@torrent)
    torrent
  end
end
