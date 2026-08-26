defmodule Exorrent.TorrentSession do
  use Supervisor
  use Task

  def start_link(torrent) do
    case Supervisor.start_link(__MODULE__, torrent, name: via(torrent.info_hash)) do
      {:ok, pid} ->
        init_dht(torrent)
        peer_source_child(torrent)
        {:ok, pid}

      error ->
        error
    end
  end

  def init(torrent) do
    children = [
      {Exorrent.PieceManager, torrent},
      {Exorrent.DiskManager, torrent},
      {DynamicSupervisor, name: peer_sup_name(torrent.info_hash), strategy: :one_for_one},
      {DynamicSupervisor, name: webseed_sup_name(torrent.info_hash), strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # -------------------------
  #      Helper functions
  # -------------------------

  # Public so PeerManager (a sibling process) can look up/reference
  # this torrent's own outbound-peer DynamicSupervisor by info_hash
  def peer_sup_name(info_hash),
    do: {:via, Registry, {Exorrent.TorrentRegistry, {:peer_sup, info_hash}}}

  def webseed_sup_name(info_hash),
    do: {:via, Registry, {Exorrent.TorrentRegistry, {:webseed_sup, info_hash}}}

  # ---------------------------------
  #          Bootstrap DHT
  # ---------------------------------
  def init_dht(t) do
    Task.Supervisor.start_child(Exorrent.TaskSupervisor, fn ->
      {:ok, pid, _id} = Exorrent.DHT.bootstrap()
      Exorrent.DHT.find_peers_and_connect(pid, t)
    end)
  end

  # ---------------------------------
  #            Init Trackers 
  # ---------------------------------
  defp peer_source_child(t) do
    if t.urls != [], do: Exorrent.Webseed.handle_webseeds(t)
    if t.trackers != [], do: Exorrent.Tracker.handle_trackers(t)
  end

  # Registers this TorrentSession itself under its info_hash
  defp via(info_hash), do: {:via, Registry, {Exorrent.TorrentRegistry, {:session, info_hash}}}
end
