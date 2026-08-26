defmodule Exorrent.DHT do
  alias Exorrent.Tracker

  require Logger

  @min 6

  def new_node(),
    do: Exalia.new_node()

  # bootstrap exalia
  def bootstrap() do
    {:ok, pid, id} = Exalia.bootstrap()

    # check that the routing table is healthy enough
    amount_candidates = length(Exalia.get_contacts(pid))

    if amount_candidates < @min, do: lookup_contacts(pid, id, 3)

    {:ok, pid, id}
  end

  def find_peers_and_connect(pid, torrent) do
    Logger.info("=== DHT lookup peers ===")
    peers = Exalia.get_peers(pid, torrent.info_hash)

    Logger.info("=== Peers Obtainied ===")
    IO.inspect(peers, label: "peers")

    Tracker.init_workers(torrent, peers)
  end

  # ------------------------
  #     Private functions
  # ------------------------

  def lookup_contacts(_pid, _id, 0),
    do: nil

  def lookup_contacts(pid, id, round) do
    Exalia.lookup(pid, id)
    lookup_contacts(pid, id, round - 1)
  end
end
