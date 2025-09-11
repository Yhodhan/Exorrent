defmodule Peers.Peer do
  defstruct [:socket, :info_hash, :size, :total_pieces]

  def decode_peers(<<>>), do: []

  def decode_peers(<<a, b, c, d, port::16, rest::binary>>) do
    ip = {a, b, c, d}
    peer = {ip, port}
    [peer] ++ decode_peers(rest)
  end

  def encode_peers(%{"peers" => peer}) when is_binary(peer) do
    <<a, b, c, d, port::16>> = peer
    [{{a, b, c, d}, port}]
  end

  def encode_peers(%{"peers" => peers}),
    do: Enum.map(peers, fn p -> encode_peer(p) end)

  def encode_peer(%{"ip" => ip, "port" => port}) do
    {:ok, ip} =
      ip
      |> String.to_charlist()
      |> :inet.parse_address()

    {ip, port}
  end
end
