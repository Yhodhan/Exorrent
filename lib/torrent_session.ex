defmodule Exorrent.TorrentSession do
  use Supervisor

  def start_link(torrent) do
    case Supervisor.start_link(__MODULE__, torrent, name: via(torrent.info_hash)) do
      {:ok, pid} ->
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

  defp peer_source_child(%{type: :trackers} = t), do: Exorrent.Tracker.handle_trackers(t)
  defp peer_source_child(%{type: :webseeds} = t), do: Exorrent.Webseed.handle_webseeds(t)

  # Registers this TorrentSession itself under its info_hash
  defp via(info_hash), do: {:via, Registry, {Exorrent.TorrentRegistry, {:session, info_hash}}}
end
