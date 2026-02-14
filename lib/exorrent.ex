defmodule Exorrent do
  alias Peers.Worker
  alias Peers.Messages
  alias Exorrent.Torrent
  alias Exorrent.Tracker
  alias Peers.PieceManager
  alias Peers.PeerConnection

  require Logger

  @torrent "torrents/ubuntu-22.04.torrent"

  def init() do
    Process.flag(:trap_exit, true)

    :inets.start()
    :ssl.start()

    {:ok, torrent} = Torrent.read_torrent(@torrent)

    with {:ok, peers} <- Tracker.get_peers(torrent) do
      Logger.info("=== Init workers ===")

      init_workers(torrent, peers)

      Logger.info("=== Download in progress ===")
    else
      {:error, _} ->
        Logger.error("=== No peers found, stop download ===")
    end
  end

  def init_workers(torrent, peers),
    do: Enum.each(peers, fn peer -> connection(torrent, peer) end)

  def connection(torrent, peer) do
    Logger.debug("=== Attemp connection, peer: #{inspect(peer)} ===")

    with {:ok, socket} <- PeerConnection.peer_connect(peer),
         {:ok, worker_pid} <- handshake(socket, torrent) do
      # ------------------
      #    Piece manager
      # ------------------
      {:ok, _pid} = PieceManager.start_link(torrent)

      # ------------------
      #    Disk manager
      # ------------------
      {:ok, _pid} = DiskManager.start_link(torrent)

      # ------------------
      #    Init downlaod
      # ------------------
      Worker.init_cycle(worker_pid)
    else
      error ->
        Logger.error("=== Error while connecting peer reason: #{error} ===")
    end
  end

  def handshake(socket, torrent) do
    Logger.info("=== Init of handhshake ===")
    handshake = Messages.build_handshake(torrent.info_hash)

    with :ok <- PeerConnection.send_handshake(socket, handshake),
         :ok <- PeerConnection.handshake_response(socket, torrent.info_hash),
         {:ok, worker_pid} <- PeerConnection.complete_handshake(socket, torrent) do
      {:ok, worker_pid}
    else
      error ->
        Logger.error("=== Handshake error reason: #{inspect(error)} ===")
        PeerConnection.terminate_connection(socket)
    end
  end

  # -------------------
  #       Helpers
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
