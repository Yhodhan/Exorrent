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

    Logger.info("=== Peers found init connection")

    connection(torrent, peers)
  end

  def connection(torrent, peers) do
    [peer | _] = peers

    case PeerConnection.peer_connect(torrent, peer) do
      {:ok, peer} ->
        {:ok, pid} = handshake(peer)
        Worker.init_cycle(pid)
        pid

      _ ->
        Logger.info("=== Connection terminated")
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
      _ ->
        PeerConnection.terminate_connection(peer)
    end
  end

  # -------------------
  #       helpers
  # -------------------

  def raw_torrent() do
    {:ok, raw_data} = File.read(@torrent)
    {:ok, torr} = Exorrent.Decoder.decode(raw_data)
    torr
  end

  def torrent() do
    {:ok, torrent} = Torrent.read_torrent(@torrent)
    torrent
  end

  def alive_peer() do
  end
end
