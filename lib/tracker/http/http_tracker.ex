defmodule Tracker.HttpTracker do
  alias Bencoder.Decoder
  alias Peers.Peer
  alias Peers.Messages

  require Logger

  def send_request(url, torrent) do
    url = Messages.http_connection_req(torrent, url)

    :inets.start()
    :ssl.start()

    case http_message(url) do
      {:ok, data} ->
        Peer.encode_peers(data)

      {:error, _reason} ->
        []
    end
  end

  def http_message(url) do
    Logger.info("=== Sending tcp message to #{url}")

    case :httpc.request(:get, {to_charlist(url), []}, [], []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        Logger.info("=== Response received")
        Decoder.decode(body)

      {:error, reason} ->
        Logger.error("=== Failed to received msg: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
