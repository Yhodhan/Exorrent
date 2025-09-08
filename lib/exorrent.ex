defmodule Exorrent do
  alias Exorrent.Torrent
  alias Exorrent.Tracker
  alias Exorrent.PeerConnection

  require Logger

  @torrent "ubuntu.torrent"

  def init() do
    {:ok, torrent} = Torrent.read_torrent(@torrent)

    peers = Tracker.get_peers(torrent)
    # init swarm of peers
    #  PeerManager.start_link(peers)

    Logger.info("=== Peers found init connection")
    connection(torrent, peers)
  end

  def connection(torrent, peers) do
    # broadcast()

    [peer | _] = peers

    case PeerConnection.peer_connect(torrent, peer) do
      {:ok, peer} ->
        handshake(peer)

      _ ->
        Logger.info("=== Connection terminated")
    end
  end

  def handshake(peer) do
    Logger.info("=== Init of handhshake")
    handshake = PeerConnection.build_handshake(peer)

    with :ok <- PeerConnection.send_handshake(peer, handshake),
         :ok <- PeerConnection.handshake_response(peer),
         {:ok, pid} <- PeerConnection.complete_handshake(peer) do
      {:ok, pid}
    else
      _ ->
        PeerConnection.terminate_connection(peer)
    end
  end

  # -------------------
  #       helpers
  # -------------------

  #  def broadcast(),
  #    do: PeerManager.broadcast()
  #
  #  def check_peers_status(),
  #    do: PeerManager.check_peers_connections()
  #
  #  def get_peers(),
  #    do: PeerManager.get_peers()
  #
  #  def get_connected_peers(),
  #    do: PeerManager.get_connected_peers()
  #
  #  def terminate_unconnected_peers(),
  #    do: PeerManager.terminate_unconnected_peers()
  #
  def reconnect() do
    #    PeerManager.kill()
    init()
  end

  # helper
  def torrent() do
    {:ok, torrent} = Torrent.read_torrent(@torrent)
    torrent
  end
end
