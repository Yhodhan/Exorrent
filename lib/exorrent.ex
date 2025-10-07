defmodule Exorrent do
  alias Exorrent.Torrent
  alias Exorrent.Tracker
  alias Peers.PeerConnection
  alias Peers.Messages
  alias Peers.Worker
  alias Peers.DownloadTable
  alias Peers.PieceManager

  require Logger

  @torrent "torrents/obs.torrent"

  def init() do
    Process.flag(:trap_exit, true)

    {:ok, torrent} = Torrent.read_torrent(@torrent)

    peers = Tracker.get_peers(torrent)

    Logger.info("=== Peers found init connection")

    case connection(torrent, peers) do
      {:error, _} ->
        Logger.error("=== Failed download")

      {:ok, worker_pid} ->
        Logger.info("=== Download in progress")
        worker_pid
    end
  end

  def connection(_torrent, []),
    do: {:error, :no_peers}

  def connection(torrent, peers) do
    [peer | rest] = peers
    Logger.debug("Attemp connection, peer: #{inspect(peer)}")

    with {:ok, socket} <- PeerConnection.peer_connect(peer),
         {:ok, worker_pid} <- handshake(socket, torrent) do
      # ---------------------
      #  Create pieces table
      # ---------------------
      DownloadTable.create_table()
      DownloadTable.fill_table(torrent.pieces_list, torrent.piece_length)

      # ------------------
      #  Piece manager
      # ------------------
      {:ok, _pid} = PieceManager.start_link(torrent)

      # ------------------
      #  disk manager
      # ------------------

      {:ok, _pid} = DiskManager.start_link(torrent)
      
      # ---------------------
      #     Init downlaod
      # ---------------------
      Worker.init_cycle(worker_pid)
      {:ok, worker_pid}
    else
      _ ->
        connection(torrent, rest)
    end
  end

  def handshake(socket, torrent) do
    Logger.info("=== Init of handhshake")
    handshake = Messages.build_handshake(torrent.info_hash)

    with :ok <- PeerConnection.send_handshake(socket, handshake),
         :ok <- PeerConnection.handshake_response(socket, torrent.info_hash),
         {:ok, worker_pid} <- PeerConnection.complete_handshake(socket, torrent) do
      {:ok, worker_pid}
    else
      error ->
        Logger.error("=== Handshake error reason: #{inspect(error)}")
        PeerConnection.terminate_connection(socket)
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
