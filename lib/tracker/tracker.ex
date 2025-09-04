defmodule Exorrent.Tracker do
  alias Tracker.HttpTracker
  alias Tracker.UdpTracker

  require Logger

  def get_peers(torrent) do
    torrent.trackers
    |> Enum.flat_map(fn tr -> request(tr, torrent) end)
    |> Enum.uniq()
  end

  def request(tracker, torrent) do
    URI.parse(tracker)
    |> send_request(torrent)
  end

  def send_request(%URI{scheme: "https"} = url, torrent),
    do: HttpTracker.send_request(url, torrent)

  def send_request(%URI{scheme: "http"} = url, torrent),
    do: HttpTracker.send_request(url, torrent)

  def send_request(%URI{scheme: "udp"} = url, torrent),
    do: UdpTracker.send_request(url, torrent)

  def send_request(_, _torrent),
    do: []
end
