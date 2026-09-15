defmodule Exorrent.DHT do
  alias Exorrent.Tracker

  require Logger

  @min 6

  def new_node(),
    do: Exalia.new_node()

  def bootstrap(pid, id) do
    Exalia.bootstrap(pid, id)
    # check that the routing table is healthy enough
    amount_candidates = length(Exalia.get_contacts(pid))

    if amount_candidates < @min, do: lookup_contacts(pid, id, 3)
  end

  def find_peers_and_connect(pid, torrent) do
    Logger.info("=== DHT lookup peers ===")
    peers = Exalia.get_peers(pid, torrent.info_hash)

    Logger.info("=== Peers Obtained ===")

    Tracker.init_workers(torrent, peers)
  end

  def announce(pid, torrent) do
    port = Application.get_env(:exorrent, :torrent_port)
    Exalia.announce_peer(pid, torrent.info_hash, port)
  end

  def store_peer({ip, port}, infohash) do
    peer = Exalia.Candidate.new(nil, ip, port)
    Exalia.Storage.store_node(infohash, peer)
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
