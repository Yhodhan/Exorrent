defmodule Exorrent.Application do
  use Application

  def start(_type, _args) do
    Process.flag(:trap_exit, true)

    port = Application.get_env(:exorrent, :torrent_port)

    children = [
      {Registry, keys: :unique, name: Exorrent.TorrentRegistry},
      {Exorrent.TorrentSupervisor, []},
      {DynamicSupervisor, name: Exorrent.InboundPeerSupervisor, strategy: :one_for_one},
      {Exorrent.Listener, port: port},
      {Task.Supervisor, name: Exorrent.TaskSupervisor}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Exorrent.Supervisor)
  end
end
