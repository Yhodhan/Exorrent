defmodule Exorrent do
  alias Exorrent.Torrent
  alias Exorrent.Tracker
  alias Exorrent.PeerManager
  alias Exorrent.PeerConnection

  require Logger

  @torrent "ubuntu.torrent"

  def init() do
    {:ok, torrent} = Torrent.read_torrent(@torrent)

    peers = Tracker.get_peers(torrent)
    # init swarm of peers
    PeerManager.start_link(peers)

    Logger.info("=== Peers found init connection")
    connection(torrent)
  end

  def connection(torrent) do
    broadcast()

    [peer | _] = get_connected_peers()

    Logger.info("=== Init of handhshake")
    {:ok, info_hash} = init_handshake(torrent, peer)

    if info_hash != torrent.info_hash do
      Logger.info("=== Received answer does not match info hash")
      PeerConnection.terminate_connection(peer.pid)
    end
  end

  def init_handshake(torrent, peer) do
    # Enum.map(peers, fn peer ->
    handshake = PeerConnection.build_handshake(torrent)

    PeerConnection.send_handshake(peer.pid, handshake)

    PeerConnection.complete_handshake(peer.pid)
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
    init()
  end

  # helper
  def torrent() do
    {:ok, torrent} = Torrent.read_torrent(@torrent)
    torrent
  end
end
