defmodule Tracker.HttpTracker do
  alias Bencoder.Decoder
  alias Peers.Peer
  alias Peers.Messages

  require Logger

  def send_request(url, torrent) do
    url = Messages.http_connection_req(torrent, url)

    IO.inspect(url, label: "Tracker url")

    :inets.start()
    :ssl.start()

    with {:ok, data} <- http_message(url),
         {:ok, answer} <- decode_answer(data) do
      Peer.peers_addresses(answer)
    else
      _ ->
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

  defp decode_answer(data) when is_binary(data),
    do: Decoder.decode(data)

  defp decode_answer(data),
    do: {:ok, data}
end
