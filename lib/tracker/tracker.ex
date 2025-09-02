defmodule Exorrent.Tracker do
  alias Exorrent.TorrentParser
  alias Tracker.HttpTracker
  alias Tracker.UdpTracker

  require Logger

  def get_peers(torrent) do
    TorrentParser.get_trackers(torrent)
    |> Enum.flat_map(fn tr ->
      uri = URI.parse(tr)
      send_request(uri, torrent)
    end)
  end

  def send_request(%URI{scheme: "https"} = url, torrent),
    do: HttpTracker.send_request(url, torrent)

  def send_request(%URI{scheme: "udp"} = url, torrent),
    do: UdpTracker.send_request(url, torrent)
end
