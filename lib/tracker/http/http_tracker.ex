defmodule Tracker.HttpTracker do
  alias Bencoder.Decoder
  alias Peers.Peer
  alias Peers.Messages

  require Logger

  def send_request(url, torrent) do
    url = Messages.http_connection_req(torrent, url)

    with {:ok, data} <- http_message(url),
         {:ok, answer} <- decode_and_validate(data) do
      Peer.peers_addresses(answer)
    else
      {:error, reason} ->
        Logger.error("The url #{url} failed with reason: #{reason} ===")
        []
    end
  end

  def http_message(url) do
    Logger.info("=== Sending tcp message to #{url} ===")

    case :httpc.request(:get, {to_charlist(url), []}, [], body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        {:ok, body}

      {:ok, {{_, status, reason}, _headers, _body}} ->
        {:error, "HTTP Status #{status} reason #{reason}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decode_and_validate(data) do
    case Decoder.decode(data) do
      {:ok, %{"failure reason" => reason}} ->
        {:error, reason}

      {:ok, data} ->
        {:ok, data}
    end
  end
end
