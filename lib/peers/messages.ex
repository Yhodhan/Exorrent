defmodule Peers.Messages do
  alias Peers.Peer

  import Bitwise

  @pstr "BitTorrent protocol"

  # ----------------------
  #         TCP
  # ----------------------
  def build_handshake(info_hash) do
    peer_id = "-EX0001-" <> :crypto.strong_rand_bytes(12)

    <<byte_size(@pstr)::8, @pstr::bytes, 0::64, info_hash::binary-size(20), peer_id::binary>>
  end

  def url_encode_raw(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map(fn byte ->
      "%" <> Base.encode16(<<byte>>, case: :upper)
    end)
    |> Enum.join()
  end

  def http_connection_req(torrent, uri, port \\ 6881) do
    peer_id = "-EX0001-" <> :crypto.strong_rand_bytes(12)
    encoded_peer_id = url_encode_raw(peer_id)
    encoded_info_hash = url_encode_raw(torrent.info_hash)

    query =
      [
        "info_hash=#{encoded_info_hash}",
        "peer_id=#{encoded_peer_id}",
        "port=#{port}",
        "uploaded=0",
        "downloaded=0",
        "left=#{torrent.size}",
        "compact=1",
        "event=started"
      ]
      |> Enum.join("&")

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

  # ---------------------
  #     Exchange msgs
  # ---------------------

  def keep_alive(),
    do: <<0::32>>

  def choke(),
    do: <<1::32, 0::8>>

  def unchoke(),
    do: <<1::32, 1::8>>

  def interested(),
    do: <<1::32, 2::8>>

  def not_interested(),
    do: <<1::32, 3::8>>

  def have(piece_index),
    do: <<5::32, 4::8, piece_index::binary>>

  def request(piece_index, begin, len),
    do: <<13::32, 6::8, piece_index::32, begin::32, len::32>>

  def piece(block_len, index, begin, block) do
    len = 9 + block_len
    <<len::32, 7::8, index::binary, begin::binary, block::binary>>
  end

  def cancel(index, begin, len),
    do: <<13::32, 8::8, index::binary, begin::binary, len::binary>>

  def port(listen_port),
    do: <<3::32, 9::8, listen_port::binary>>

  # -----------------
  #    Bitfield
  # -----------------

  def make_bitfield(bitfield, total_pieces) do
    bitfield
    |> :binary.bin_to_list()
    |> Enum.with_index()
    |> Enum.flat_map(fn {byte, byte_index} -> bits(byte, byte_index, total_pieces) end)
    |> MapSet.new()
  end

  # pick a bit, apply a mask
  defp bits(byte, byte_index, total_pieces) do
    for bit_index <- 0..7,
        has_piece?(byte, bit_index),
        piece = byte_index * 8 + bit_index,
        piece < total_pieces,
        do: piece
  end

  defp has_piece?(byte, bit_index) do
    mask = 1 <<< (7 - bit_index)
    (byte &&& mask) != 0
  end
end
