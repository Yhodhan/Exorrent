defmodule Tracker.HttpTracker do
  alias Exorrent.Decoder

  require Logger

  def send_request(url, torrent) do
    url = http_connection_req(torrent, url)

    :inets.start()
    :ssl.start()

    case http_message(url) do
      {:ok, data} ->
        encode_peers(data)

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

  # ------------------
  # Private functions
  # ------------------

  defp http_connection_req(torrent, uri, port \\ 6881) do
    params = %{
      "info_hash" => torrent.info_hash,
      "peer_id" => :crypto.strong_rand_bytes(20),
      "port" => port,
      "uploaded" => 0,
      "downloaded" => 0,
      "left" => torrent.size,
      "compact" => 1,
      "event" => "started"
    }

    query = URI.encode_query(params)
    "#{uri.scheme}://#{uri.authority}#{uri.path}?#{query}"
  end

  defp encode_peers(%{"peers" => peer}) when is_binary(peer) do
    <<a, b, c, d, port::16>> = peer
    [{{a, b, c, d}, port}]
  end

  defp encode_peers(%{"peers" => peers}),
    do: Enum.map(peers, fn p -> encode_peer(p) end)

  defp encode_peer(%{"ip" => ip, "port" => port}) do
    {:ok, ip} =
      ip
      |> String.to_charlist()
      |> :inet.parse_address()

    {ip, port}
  end
end
