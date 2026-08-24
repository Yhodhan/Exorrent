defmodule Exorrent.TorrentSupervisor do
  use DynamicSupervisor

  def start_link(_opts),
    do: DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok),
    do: DynamicSupervisor.init(strategy: :one_for_one)

  def start_torrent(torrent),
    do: DynamicSupervisor.start_child(__MODULE__, {Exorrent.TorrentSession, torrent})

  def stop_torrent(info_hash) do
    case Registry.lookup(Exorrent.TorrentRegistry, {:session, info_hash}) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end
end
