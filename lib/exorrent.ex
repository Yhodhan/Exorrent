defmodule Exorrent do
  alias Exorrent.Torrent

  require Logger

  @torrent "torrents/ubuntu.torrent"

  # ---------------------------------------------------

  def init() do
    Logger.info("=== Init torrent ===")
    {:ok, torrent} = Torrent.read_torrent(@torrent)
    Exorrent.TorrentSupervisor.start_torrent(torrent)
  end

  # -------------------
  #       Helpers
  # -------------------

  def raw_torrent() do
    {:ok, raw_data} = File.read(@torrent)
    {:ok, torr} = Bencoder.Decoder.decode(raw_data)
    torr
  end

  def torrent() do
    {:ok, torrent} = Torrent.read_torrent(@torrent)
    torrent
  end
end
