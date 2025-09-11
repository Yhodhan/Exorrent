defmodule Exorrent do
  alias Exorrent.Torrent
  alias Exorrent.Tracker
  alias Peers.PeerConnection
  alias Peers.Messages
  alias Peers.Worker

  require Logger

  @torrent "torrents/linuxmint.torrent"

  def init() do
    {:ok, torrent} = Torrent.read_torrent(@torrent)

    peers = Tracker.get_peers(torrent)

    Logger.info("=== Peers found init connection")

    connection(torrent, peers)
  end

  def connection(torrent, peers) do
    [peer | _] = peers

    with {:ok, peer} <- PeerConnection.peer_connect(torrent, peer),
         {:ok, worker_pid} <- handshake(peer) do
      Worker.init_cycle(worker_pid)
      worker_pid
    end
  end

  def handshake(peer) do
    Logger.info("=== Init of handhshake")
    handshake = Messages.build_handshake(peer)

    with :ok <- PeerConnection.send_handshake(peer, handshake),
         :ok <- PeerConnection.handshake_response(peer),
         {:ok, worker_pid} <- PeerConnection.complete_handshake(peer) do
      {:ok, worker_pid}
    else
      error ->
        Logger.error("=== Handshake error reason: #{inspect(error)}")
        PeerConnection.terminate_connection(peer)
    end
  end

  # -------------------
  #       helpers
  # -------------------

  def raw_torrent() do
    {:ok, raw_data} = File.read(@torrent)
    {:ok, torr} = Bencoder.Decoder.decode(raw_data)
    torr
  end

  def torrent() do
    {:ok, torrent} = Torrent.read_torrent(@torrent)
    torrent
  end
end
