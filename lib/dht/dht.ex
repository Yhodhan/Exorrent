defmodule Exorrent.DHT do
  alias Exorrent.Tracker

  require Logger

  def new_node(),
    do: Exalia.new_node()

  def bootstrap(pid, id) do
    Exalia.bootstrap(pid, id)
    # check that the routing table is healthy enough

    lookup_contacts(pid, id)
  end

  def find_peers_and_connect(pid, id, torrent) do
    Logger.info("=== DHT lookup peers ===")

    lookup_contacts(pid, id)
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

  def lookup_contacts(pid, id),
    do: Exalia.lookup(pid, id)
end
