defmodule Exorrent do
  alias Exorrent.Torrent
  alias Exorrent.Tracker
  alias Exorrent.PeerConnection
  alias Peers.Messages
  alias Peers.Worker

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
        {:ok, pid} = handshake(peer)
        download(pid)

      _ ->
        Logger.info("=== Connection terminated")
    end
  end

  def handshake(peer) do
    Logger.info("=== Init of handhshake")
    handshake = Messages.build_handshake(peer)

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

  def download(pid) do
    Worker.download(pid)
  end

  def reconnect() do
    #    PeerManager.kill()
    init()
  end

  def torrent() do
    {:ok, torrent} = Torrent.read_torrent(@torrent)
    torrent
  end
end
