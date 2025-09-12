defmodule Peers.Peer do
  defstruct [:socket, :info_hash, :size, :total_pieces]

  def decode_peers(<<>>), do: []

  def decode_peers(<<a, b, c, d, port::16, rest::binary>>) do
    ip = {a, b, c, d}
    peer = {ip, port}
    [peer] ++ decode_peers(rest)
  end

  def peers_addresses(%{"peers" => peers}) when is_binary(peers),
    do: decode_peers(peers)

  def peers_addresses(%{"peers" => peers}),
    do: Enum.map(peers, fn p -> peer_address(p) end)

  # ----------------------
  #    Private functions
  # ----------------------
  defp peer_address(%{"ip" => ip, "port" => port}) do
    {:ok, ip} =
      ip
      |> String.to_charlist()
      |> :inet.parse_address()

    {ip, port}
  end
end
