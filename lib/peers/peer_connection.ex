defmodule Exorrent.PeerConnection do
  alias Exorrent.Peer
  alias Peers.Worker

  require Logger

  @pstr "BitTorrent protocol"

  def peer_connect(torrent, peer) do
    {ip, port} = peer

    case :gen_tcp.connect(ip, port, [:binary, packet: :raw, active: false]) do
      {:ok, socket} ->
        Logger.info("=== Succesfull connection #{inspect(ip)}:#{port}")

        {:ok, update_peer(torrent, socket)}

      {:error, reason} ->
        Logger.error("=== Failed to connect #{inspect(ip)}:#{port} reason=#{inspect(reason)}")
        {:error, reason}
    end
  end

  def send_handshake(peer, msg) do
    %Peer{socket: socket} = peer

    Logger.info("=== Sending msg to socket: #{inspect(socket)}")

    :gen_tcp.send(socket, msg)
  end

  def handshake_response(peer) do
    Logger.info("Reading data from socket: #{inspect(peer.socket)}")
    %Peer{socket: socket, info_hash: info_hash} = peer

    with {:ok, <<len::8>>} <- :gen_tcp.recv(socket, 1),
         {:ok, pstr} <- :gen_tcp.recv(socket, len),
         {:ok, _reserved} <- :gen_tcp.recv(socket, 8),
         {:ok, hash} <- :gen_tcp.recv(socket, 20) do
      case {pstr, hash} do
        {@pstr, ^info_hash} -> :ok
        _ -> :error
      end
    end
  end

  def complete_handshake(peer) do
    Logger.info("=== Completing handshake")
    %Peer{socket: socket} = peer

    case :gen_tcp.recv(socket, 20) do
      {:ok, _peer_id} ->
        conn_data = get_data(peer)
        {:ok, pid} = Worker.start_link(conn_data)
        :gen_tcp.controlling_process(socket, pid)

        {:ok, pid}

      _ ->
        :error
    end
  end

  def terminate_connection(peer) do
    Logger.info("=== Terminating connection to socket: #{peer.socket}")
    :gen_tcp.close(peer.socket)
  end

  # ---------------------
  #       Helper
  # ---------------------

  defp update_peer(torrent, socket) do
    %Peer{
      socket: socket,
      info_hash: torrent.info_hash,
      size: torrent.size
    }
  end

  defp get_data(peer) do
    %{
      socket: peer.socket,
      info_hash: peer.info_hash,
      size: peer.size
    }
  end

  # --------------------
  #     Connection
  # --------------------


  def parse_tcp_response(msg) do
    case msg do
      <<0::32, _id::8, _>> ->
        :keep_alive

      <<1::32, 0::8, _>> ->
        :choke

      <<0::32, 1::8, _>> ->
        :unchoke

      <<1::32, 2::8, _>> ->
        :interested

      <<1::32, 3::8, _>> ->
        :not_interested
    end
  end
end
