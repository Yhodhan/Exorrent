defmodule Exorrent.Peer do
  defstruct [:socket, :info_hash, :size]

  def parse_peers(<<>>), do: []

  def parse_peers(<<a, b, c, d, port::16, rest::binary>>) do
    ip = {a, b, c, d}
    peer = {ip, port}
    [peer] ++ parse_peers(rest)
  end
end
