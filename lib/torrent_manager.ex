defmodule Exorrent.TorrentManager do
  use GenServer

  require Logger

  @announce_interval :timer.minutes(5)
  @workers_discovery :timer.minutes(5)

  def start_link(torrent \\ %{}),
    do: GenServer.start_link(__MODULE__, torrent)

  def init(torrent) do
    Logger.info("=== Init Torrent Manager ===")

    send(self(), :init_peer_sources)

    {:ok, %{torrent: torrent}}
  end

  def handle_info(:init_peer_sources, %{torrent: t} = state) do
    Logger.info("=== Init Peer sources ===")

    if t.urls != [], do: Exorrent.Webseed.handle_webseeds(t)
    if t.trackers != [], do: Exorrent.Tracker.handle_trackers(t)

    {:ok, pid} = bootstrap_dht(t)

    schedule_dht_announce()
    schedule_worker_discovery()

    {:noreply, Map.put(state, :pid, pid)}
  end

  def handle_info(:workers_discovery, %{pid: pid, torrent: t} = state) do
    Exorrent.DHT.find_peers_and_connect(pid, t)

    schedule_worker_discovery()

    {:noreply, state}
  end

  def handle_info(:announce, %{pid: pid, torrent: t} = state) do
    Exorrent.DHT.announce(pid, t)

    schedule_dht_announce()

    {:noreply, state}
  end

  # ---------------------------------
  #          Bootstrap DHT
  # ---------------------------------

  def bootstrap_dht(t) do
    {:ok, pid, id} = Exorrent.DHT.new_node()

    Task.Supervisor.start_child(Exorrent.TaskSupervisor, fn ->
      Exorrent.DHT.bootstrap(pid, id)

      Exorrent.DHT.find_peers_and_connect(pid, t)
      Exorrent.DHT.announce(pid, t)
    end)

    {:ok, pid}
  end

  def schedule_dht_announce(),
    do: Process.send_after(self(), :announce, @announce_interval)

  def schedule_worker_discovery(),
    do: Process.send_after(self(), :workers_discovery, @workers_discovery)
end
