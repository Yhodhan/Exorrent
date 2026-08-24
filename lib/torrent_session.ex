defmodule Exorrent.TorrentSession do
  use Supervisor

  def start_link(torrent) do
    Supervisor.start_link(__MODULE__, torrent, name: via(torrent.info_hash))
  end

  def init(torrent) do
    children = [
      {Exorrent.PieceManager, torrent},
      {Exorrent.DiskManager, torrent},
      {DynamicSupervisor, name: peer_sup_name(torrent), strategy: :one_for_one},
      {Exorrent.PeerManager, torrent},
      peer_source_child(torrent)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # -------------------------
  #      Helper functions
  # -------------------------
  defp peer_source_child(%{type: :trackers} = t), do: {Exorrent.Tracker, t}
  defp peer_source_child(%{type: :webseeds} = t), do: {Exorrent.Webseed, t}

  # Registers this TorrentSession itself under its info_hash
  defp via(info_hash), do: {:via, Registry, {Exorrent.TorrentRegistry, {:session, info_hash}}}

  # Public so PeerManager (a sibling process) can look up/reference
  # this torrent's own outbound-peer DynamicSupervisor by info_hash
  defp peer_sup_name(info_hash),
    do: {:via, Registry, Exorrent.TorrentRegistry, {:peer_sup, info_hash}}
end
