defmodule Exorrent.Tracker do
  alias Peers.Worker
  alias Peers.Messages
  alias Tracker.UdpTracker
  alias Tracker.HttpTracker
  alias Peers.PeerConnection

  require Logger

  def handle_trackers(torrent) do
    with {:ok, peers} <- get_peers(torrent) do
      Logger.info("=== Init workers ===")

      init_workers(torrent, peers)

      Logger.info("=== Download in progress ===")
    else
      {:error, _} ->
        Logger.error("=== No peers found, stop download ===")
    end
  end

  # ---------------------------------------------------

  def init_workers(torrent, peers),
    do: Enum.each(peers, fn peer -> connection(torrent, peer) end)

  # ---------------------------------------------------
  def connection(torrent, peer) do
    Logger.debug("=== Attemp connection, peer: #{inspect(peer)} ===")

    with {:ok, socket} <- PeerConnection.peer_connect(peer),
         {:ok, worker_pid} <- handshake(socket, torrent) do
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

  def get_peers(torrent) do
    peers =
      torrent.urls
      |> Enum.flat_map(fn tr -> request(tr, torrent) end)
      |> Enum.uniq()

    case peers do
      [] ->
        {:error, peers}

      _ ->
        {:ok, peers}
    end
  end

  def request(tracker, torrent) do
    URI.parse(tracker)
    |> send_request(torrent)
  end

  def send_request(%URI{scheme: "https"} = url, torrent),
    do: HttpTracker.send_request(url, torrent)

  def send_request(%URI{scheme: "http"} = url, torrent),
    do: HttpTracker.send_request(url, torrent)

  def send_request(%URI{scheme: "udp"} = url, torrent),
    do: UdpTracker.send_request(url, torrent)

  def send_request(_, _torrent),
    do: []
end
