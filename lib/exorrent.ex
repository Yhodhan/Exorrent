defmodule Exorrent do
  alias Exorrent.Torrent
  alias Exorrent.Tracker
  alias Exorrent.Webseed
  alias Exorrent.PieceManager

  require Logger

  @torrent "torrents/archlinux.torrent"

  # ---------------------------------------------------

  def init() do
    Process.flag(:trap_exit, true)

    :inets.start()
    :ssl.start()

    {:ok, torrent} = Torrent.read_torrent(@torrent)

    # ------------------
    #    Piece manager
    # ------------------
    {:ok, _pid} = PieceManager.start_link(torrent)

    # ------------------
    #    Disk manager
    # ------------------
    {:ok, _pid} = DiskManager.start_link(torrent)

    case torrent.type do
      :trackers -> Tracker.handle_trackers(torrent)
      :webseeds -> Webseed.handle_webseeds(torrent)
    end
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
