defmodule Peers.Messages do
  alias Exorrent.Peer
  @pstr "BitTorrent protocol"

  # ----------------------
  #         TCP
  # ----------------------
  def build_handshake(peer) do
    pstrlen = byte_size(@pstr)
    reserved = <<0::64>>
    info_hash = peer.info_hash
    peer_id = "-EX0001-" <> :crypto.strong_rand_bytes(12)

    <<pstrlen::8, @pstr::binary, reserved::binary, info_hash::binary-size(20), peer_id::binary>>
  end

  def http_connection_req(torrent, uri, port \\ 6881) do
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

  # ----------------------
  #         UDP
  # ----------------------

  def udp_connection_req() do
    protocol_id = 0x41727101980
    tx_id = :crypto.strong_rand_bytes(4)

    <<protocol_id::64, 0::32, tx_id::binary>>
  end

  def udp_announce_req(connection_id, torrent, port \\ 6881) do
    action = 1
    tx_id = :crypto.strong_rand_bytes(4)
    info_hash = torrent.info_hash
    downloaded = 0
    peer_id = :crypto.strong_rand_bytes(20)
    left = torrent.size
    uploaded = 0
    event = 0
    ip_address = 0
    key = :crypto.strong_rand_bytes(4)
    num_want = -1

    <<connection_id::64, action::32, tx_id::binary, info_hash::binary, peer_id::binary, left::64,
      downloaded::64, uploaded::64, event::32, ip_address::32, key::binary, num_want::signed-32,
      port::16>>
  end

  def parse_udp_message(message) do
    case message do
      # connection
      <<0::32, tx_id::32, conn_id::64>> ->
        %{action: :connection, tx_id: tx_id, conn_id: conn_id}

      # announce
      <<1::32, tx_id::32, interval::32, leechers::32, seeders::32, peers::binary>> ->
        peers_ips = Peer.decode_peers(peers)

        %{
          action: :announce,
          tx_id: tx_id,
          interval: interval,
          leechers: leechers,
          seeders: seeders,
          peers: peers_ips
        }

      _ ->
        :unknown_operation
    end
  end
end
